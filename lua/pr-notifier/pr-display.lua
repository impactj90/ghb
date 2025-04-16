local github_handler = require("pr-notifier.github-handler")
local pr_state = require("pr-notifier.pr-state")

local M = {
	details_buf = nil,
	file_buf = nil,
}

function M.setup()
end

local function setup_comment_keymaps(buf)
	pcall(vim.api.nvim_buf_del_keymap, buf, 'n', "<CR>")

	vim.keymap.set('n', '<CR>', function()
		local cursor = vim.api.nvim_win_get_cursor(0)
		local line = cursor[1] - 1 -- Convert to 0-indexed

		local ns_id = vim.api.nvim_create_namespace("pr_comments")
		local extmarks = vim.api.nvim_buf_get_extmarks(buf, ns_id, { line, 0 }, { line, -1 }, {})
		if #extmarks > 0 then
			vim.notify("comment extmark found", vim.log.levels.INFO)
			M.show_comment_details()
		else
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), 'n', false)
		end
	end, {
		buffer = buf,
		noremap = true,
		silent = true,
		desc = "Show PR comment details"
	})
end

function M.show_pr_details(pr_number, owner, repo)
	M.details_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(M.details_buf)

	vim.api.nvim_buf_set_option(M.details_buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(M.details_buf, "swapfile", false)
	vim.api.nvim_buf_set_option(M.details_buf, "modifiable", true)

	pr_state.set("buffers.details", M.details_buf)

	github_handler.get_prs_details(pr_number, function(pr_data)
		vim.schedule(function()
			local lines = {}
			table.insert(lines, "PR #" .. pr_data.number .. ": " .. pr_data.title)
			table.insert(lines, "commit: " .. pr_data.head.sha)
			table.insert(lines, "")
			table.insert(lines, "Author: " .. pr_data.user.login)
			table.insert(lines, "Status: " .. (pr_data.draft and "DRAFT" or pr_data.state))
			table.insert(lines, "Created: " .. pr_data.created_at:sub(1, 10))
			table.insert(lines, "")

			-- Set the lines in the buffer
			vim.api.nvim_buf_set_lines(M.details_buf, 0, -1, false, lines)

			github_handler.get_prs_files(pr_number, function(files_data)
				vim.schedule(function()
					local current_lines = vim.api.nvim_buf_get_lines(M.details_buf, 0, -1, false)

					local new_lines = {}

					for _, line in ipairs(current_lines) do
						table.insert(new_lines, line)
					end

					table.insert(new_lines, "Files Changed (" .. #files_data .. "):")
					table.insert(lines, "")
					table.sort(files_data, function(a, b) return a.filename < b.filename end)

					-- Add file entries
					for i, file in ipairs(files_data) do
						local status_symbol = "M"
						if file.status == "added" then
							status_symbol = "A"
						elseif file.status == "removed" then
							status_symbol = "D"
						end

						local changes = "+" .. file.additions .. " -" .. file.deletions
						local line = string.format("%d. [%s] %s (%s)", i, status_symbol,
							file.filename, changes)
						table.insert(new_lines, line)
					end

					-- Update buffer
					vim.api.nvim_buf_set_lines(M.details_buf, 0, -1, false, new_lines)

					pr_state.set("pr_number", pr_number)
					pr_state.set("owner", owner)
					pr_state.set("repo", repo)
					pr_state.set("files", files_data)

					-- Set up file selection keymap
					vim.api.nvim_buf_set_keymap(M.details_buf, 'n', '<CR>',
						':lua require("pr-notifier.pr-display").handle_file_selection()<CR>',
						{ noremap = true, silent = true })

					-- Print confirmation
					table.insert(new_lines,
						"Press <Enter> on a file to view diff | q to close and return")
				end)
			end)
		end)
	end)

	vim.api.nvim_buf_set_keymap(M.details_buf, "n", "q", ":q<CR>", { noremap = true, silent = true })
end

function M.handle_file_selection()
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	local current_line = vim.api.nvim_buf_get_lines(M.details_buf, cursor_line - 1, cursor_line, false)[1]

	if not current_line:match("^%d+%. %[") then
		vim.notify("Not a file entry line: " .. current_line, vim.log.levels.WARN)
		return
	end

	local file_num = tonumber(current_line:match("^(%d+)%."))
	if not file_num then
		vim.notify("Could not extract file number from line", vim.log.levels.ERROR)
		return
	end

	local files = pr_state.get("files")
	if not files then
		vim.notify("No files selected" .. vim.inspect(pr_state.get("files")), vim.log.levels.ERROR)
		return
	end

	if file_num > 0 and file_num <= #files then
		local file = files[file_num]
		pr_state.set("selected_file", file)
		M.view_file_diff(file)
	else
		vim.notify("Invalid file number: " .. file_num, vim.log.levels.ERROR)
	end
end

function M.view_file_diff(file)
	if M.file_buf then
		M.clear_buffers(vim.api.nvim_get_current_win(), M.file_buf)
	end

	M.file_buf = vim.api.nvim_create_buf(false, true)

	vim.api.nvim_buf_set_option(M.file_buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(M.file_buf, "swapfile", false)
	vim.api.nvim_buf_set_option(M.file_buf, "modifiable", true)
	vim.api.nvim_buf_set_option(M.file_buf, "filetype", "diff")

	pr_state.set("buffers.file", M.file_buf)

	vim.api.nvim_buf_set_lines(M.file_buf, 0, 1, false, {
		"Loading file diff for " .. file.filename .. "...",
		"",
		"Press <Backspace> to close and return to original window"
	})

	if M.file_buf and M.details_buf then
		local details_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(details_win, M.details_buf)

		vim.cmd("split")

		-- The current window is now the newly created split window
		local file_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_height(file_win, 40)
		vim.api.nvim_win_set_buf(file_win, M.file_buf)

		vim.api.nvim_buf_set_keymap(M.file_buf, 'n', 'q',
			':lua require("pr-notifier.pr-display").clear_buffers(' ..
			M.file_buf .. ', ' .. file_win .. ')<CR>',
			{ noremap = true, silent = true })
	end


	if file.patch then
		local line_mapping = {}
		local buf_lines = 1

		-- Generate diff header
		local diff_header = {
			"diff --git a/" .. file.filename .. " b/" .. file.filename,
			"--- a/" .. file.filename,
			"+++ b/" .. file.filename,
		}

		local diff_lines = {}
		for line in file.patch:gmatch("[^\r\n]+") do
			table.insert(diff_lines, line)
		end

		for _ = 1, #diff_header do
			buf_lines = buf_lines + 1
		end

		for i, _ in ipairs(diff_lines) do
			line_mapping[buf_lines] = i - 1
			buf_lines = buf_lines + 1
		end

		-- Combine header and diff
		local lines = {}
		for _, line in ipairs(diff_header) do
			table.insert(lines, line)
		end
		for _, line in ipairs(diff_lines) do
			table.insert(lines, line)
		end

		pr_state.set("filename", file.filename)
		pr_state.set("commit_id", file.sha)
		pr_state.set("line_mapping", line_mapping)

		-- Set the lines in the buffer
		vim.api.nvim_buf_set_lines(M.file_buf, 0, -1, false, lines)
	else
		-- If patch is not available (for large diffs), show a message
		vim.api.nvim_buf_set_lines(M.file_buf, 0, -1, false, {
			"Patch not available for " .. file.filename,
			"This usually happens for large files.",
			"",
			"Press <Backspace> to return to PR details | q to exit to code"
		})
	end

	local pr_number = pr_state.get("pr_number")
	github_handler.get_pr_comments(pr_number, function(comments)
		vim.schedule(function()
			local comments_handler = require("pr-notifier.comments-handler")
			local organized_comments = comments_handler.organize_comments_by_file(comments)

			pr_state.set("organized_comments", organized_comments)

			M.display_comments_for_file(file.filename)
		end)
	end)

	vim.api.nvim_buf_set_keymap(M.file_buf, 'n', '<Space>co',
		':lua require("pr-notifier.pr-display").add_comment_at_current_line()<CR>',
		{ noremap = true, silent = true })

	-- Set up keymaps
	vim.api.nvim_buf_set_keymap(M.file_buf, 'n', '<BS>',
		':q<CR>',
		{ noremap = true, silent = true })
end

function M.clear_buffers(win, buf)
	-- Check if buffer exists and is valid before attempting to delete
	if buf and vim.api.nvim_buf_is_valid(buf) then
		-- Try to delete the buffer with error handling
		local success, err = pcall(function()
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		if not success then
			vim.notify("Failed to delete buffer: " .. tostring(err), vim.log.levels.ERROR)
		end
	else
		vim.notify("Buffer is not valid: " .. (buf or "nil"), vim.log.levels.WARN)
	end

	-- You might also want to close the window if it's valid
	if win and vim.api.nvim_win_is_valid(win) then
		pcall(vim.api.nvim_win_close, win, true)
	end
end

function M.add_comment_at_current_line()
	local pr_data = pr_state.get("buffers.details")

	-- Get current line number
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line_num = cursor[1]

	-- Open a small floating window for comment input
	local comment_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(comment_buf, 0, -1, false,
		{ "", "Type your comment here (Press <CR> to submit, <Esc> to cancel)" })

	local win_width = 70
	local win_height = 10

	local win = vim.api.nvim_open_win(comment_buf, true, {
		relative = "cursor",
		width = win_width,
		height = win_height,
		row = 1,
		col = 0,
		style = "minimal",
		border = "rounded"
	})

	-- Set insert mode and mappings
	vim.cmd("startinsert!")

	vim.api.nvim_buf_set_keymap(comment_buf, "i", "<CR>", "", {
		callback = function()
			local comment_text = vim.api.nvim_buf_get_lines(comment_buf, 0, -1, false)
			comment_text = table.concat(comment_text, "\n")

			-- Close the comment window
			vim.api.nvim_win_close(win, true)

			-- Submit the comment via API
			github_handler.submit_comment(pr_data.pr_number, file.filename, line_num, comment_text)
		end,
		noremap = true
	})

	vim.api.nvim_buf_set_keymap(comment_buf, "i", "<Esc>", "", {
		callback = function()
			vim.api.nvim_win_close(win, true)
		end,
		noremap = true
	})
end

function M.display_comments_for_file(filename)
	local buf = pr_state.get("buffers.file")

	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		vim.notify("file_buf is not valid.", vim.log.levels.ERROR)
		return
	end

	local organized_comments = pr_state.get("organized_comments")
	local file_comments = organized_comments[filename]
	if not file_comments then
		vim.notify("no commens were found", vim.log.levels.INFO)
		return
	end
	local ns_id = vim.api.nvim_create_namespace("pr_comments")

	-- Clear existing comments
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

	-- For each line with comments
	for line_num, comments in pairs(file_comments) do
		-- Find the actual line number in our buffer (might be different because of diff view)
		local buffer_line = M.find_matching_line_in_buffer(buf, line_num, filename)

		if buffer_line and buffer_line > 0 then
			-- For each comment on this line
			for i, comment in ipairs(comments) do
				vim.api.nvim_buf_set_extmark(buf, ns_id, buffer_line, 0, {
					virt_text = { { " 💬 " .. comment.body } },
					virt_text_pos = "eol",
					priority = 100,
					id = comment.id or i,
				})

				if not pr_state.get("comment_data") then
					pr_state.set("comment_data", {})
				end

				local comment_data = pr_state.get("comment_data")

				comment_data[comment.id or i] = {
					user = comment.user,
					body = comment.body,
					line = buffer_line,
					created_at = comment.created_at,
				}

				pr_state.set("comment_data", comment_data)
			end
		end
	end
	setup_comment_keymaps(buf)
end

function M.show_comment_details()
	local buf = pr_state.get("buffers.file")
	local ns_id = vim.api.nvim_create_namespace("pr_comments")

	-- Get the current line
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = cursor[1] - 1 -- Convert to 0-indexed

	-- Check if there's a comment extmark on this line
	local extmarks = vim.api.nvim_buf_get_extmarks(buf, ns_id, { line, 0 }, { line, -1 }, {})

	if #extmarks > 0 then
		-- Get the first extmark's ID (which we set to the comment ID)
		local extmark = extmarks[1]
		local comment_id = extmark[4] -- sign_id should be in this position

		-- Get the comment data
		local comment_data = pr_state.get("comment_data")
		if comment_data and comment_data[comment_id] then
			local comment = comment_data[comment_id]

			-- Create a floating window with the comment details
			local comment_buf = vim.api.nvim_create_buf(false, true)

			-- Format the comment nicely
			local comment_lines = {
				"Comment by " .. comment.user,
				string.rep("-", 30),
				"", -- Empty line before comment text
			}

			-- Split comment body into lines and add them
			for part in comment.body:gmatch("[^\r\n]+") do
				table.insert(comment_lines, part)
			end

			-- Add timestamp at the bottom
			table.insert(comment_lines, "")
			table.insert(comment_lines, string.rep("-", 30))

			-- Format the date nicely if available
			if comment.created_at then
				local date_str = comment.created_at:match("^(%d%d%d%d%-%d%d%-%d%d)")
				table.insert(comment_lines, "Posted on: " .. (date_str or comment.created_at))
			end

			-- Add a line about how to close the window
			table.insert(comment_lines, "")
			table.insert(comment_lines, "Press 'q' to close this window")

			vim.api.nvim_buf_set_lines(comment_buf, 0, -1, false, comment_lines)

			-- Calculate a good size for the floating window
			local max_width = 0
			for _, line in ipairs(comment_lines) do
				max_width = math.max(max_width, #line)
			end

			local win_width = math.min(max_width + 4, 80) -- Cap at 80 chars wide
			local win_height = math.min(#comment_lines, 20) -- Cap at 20 lines tall

			-- Open the floating window near the comment
			local win = vim.api.nvim_open_win(comment_buf, true, {
				relative = "win",
				row = line,              -- Position at the commented line
				col = vim.api.nvim_win_get_width(0) - win_width - 5, -- Position from the right side
				width = win_width,
				height = win_height,
				style = "minimal",
				border = "rounded"
			})

			-- Make the buffer read-only
			vim.api.nvim_buf_set_option(comment_buf, "modifiable", false)

			-- Add a mapping to close the window with 'q'
			vim.api.nvim_buf_set_keymap(comment_buf, 'n', 'q',
				':lua vim.api.nvim_win_close(' .. win .. ', true)<CR>',
				{ noremap = true, silent = true })
		end
	end
end

-- @return line number in buffer or nil if not found
function M.find_matching_line_in_buffer(buf, target_line, filename)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	-- For diff format, find lines that look like @@ -X,Y +A,B @@
	-- which indicate line numbers
	local current_line_offset = 0
	local in_target_file = false

	for i, line in ipairs(lines) do
		-- Check if we're in the right file section (for multi-file diffs)
		if line:match("^%+%+%+ b/" .. filename:gsub("%-", "%%-")) then
			in_target_file = true
		elseif line:match("^%+%+%+ b/") then
			in_target_file = false
		end

		if in_target_file then
			-- Look for hunk headers
			local hunk_match = line:match("^@@ %-(%d+),(%d+) %+(%d+),(%d+) @@")
			if hunk_match then
				local _, _, new_start, _ = line:match("^@@ %-(%d+),(%d+) %+(%d+),(%d+) @@")
				current_line_offset = tonumber(new_start) - i - 1
			end

			-- If this is our target line
			if current_line_offset + i == target_line then
				return i - 1 -- -1 because Neovim is 0-indexed
			end
		end
	end

	return target_line - 1
end

function M.submit_comment(pr_number, filename, line_num, body)
	-- This will use the GitHub API to submit a comment
	-- You'll need to implement this in your github-handler.lua
	github_handler.create_pr_comment(pr_number, filename, line_num, body, function(success)
		if success then
			vim.notify("Comment added successfully", vim.log.levels.INFO)
			-- Refresh comments
			github_handler.get_pr_comments(pr_number, function(comments)
				vim.notify("submitted" .. comments, vim.log.levels.INFO)
			end)
		else
			vim.notify("Failed to add comment", vim.log.levels.ERROR)
		end
	end)
end

return M
