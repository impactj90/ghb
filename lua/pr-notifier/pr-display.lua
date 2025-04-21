local github_handler = require("pr-notifier.github-handler")
local pr_state = require("pr-notifier.pr-state")

local M = {
	details_buf = nil,
	file_buf = nil,
}

function M.setup()
end

local function wrap_text(text, max_width)
	local lines = {}
	for line in text:gmatch("[^\n]+") do
		while #line > max_width do
			table.insert(lines, line:sub(1, max_width))
			line = line:sub(max_width + 1)
		end
		table.insert(lines, line)
	end

	return lines
end

local function setup_comment_keymaps(buf)
	vim.notify("setup_comment_keymaps for buffer: " .. buf, vim.log.levels.INFO)
	pcall(vim.api.nvim_buf_del_keymap, buf, 'n', "<leader>cr")

	vim.keymap.set('n', '<leader>cr', function()
		local cursor = vim.api.nvim_win_get_cursor(0)
		local line = cursor[1] - 1 -- Convert to 0-indexed

		local ns_id = vim.api.nvim_create_namespace("pr_comments")
		local extmarks = vim.api.nvim_buf_get_extmarks(buf, ns_id, { line, 0 }, { line, -1 }, {})
		if #extmarks > 0 then
			vim.notify("comment extmark found", vim.log.levels.INFO)
			M.show_comment_details()
		else
			vim.notify("no comment extmark found", vim.log.levels.INFO)
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
					pr_state.set("base_branch", pr_data.base.ref)
					pr_state.set("head_branch", pr_data.head.ref)

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
		local selected_file = files[file_num]
		pr_state.set("selected_file", selected_file.filename)

		if pr_state.get("base_branch") and pr_state.get("head_branch") then
			local baseRef = pr_state.get("base_branch")
			local headRef = pr_state.get("head_branch")

			local file_contents = {}
			local completed_requests = 0

			github_handler.get_pr_file_content(selected_file.filename, baseRef,
				function(file_content)
					vim.schedule(function()
						file_contents[1] = vim.fn.system('base64 --decode',
							file_content.content)

						completed_requests = completed_requests + 1
						if completed_requests == 2 then
							M.view_file_diff(selected_file, file_contents)
						end
					end)
				end)

			github_handler.get_pr_file_content(selected_file.filename, headRef,
				function(file_content)
					vim.schedule(function()
						file_contents[2] = vim.fn.system('base64 --decode',
							file_content.content)

						completed_requests = completed_requests + 1
						if completed_requests == 2 then
							M.view_file_diff(selected_file, file_contents)
						end
					end)
				end)
		end
	else
		vim.notify("Invalid file number: " .. file_num, vim.log.levels.ERROR)
	end
end

function M.view_file_diff(selected_file, file_contents)
	local base_branch = pr_state.get("base_branch")
	local head_branch = pr_state.get("head_branch")

	local base_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(base_buf, "[BASE: " .. base_branch .. "] ")
	vim.api.nvim_buf_set_lines(base_buf, 0, -1, false, vim.split(file_contents[1], "\n"))
	pr_state.set("buffers.base_buf", base_buf)

	local pr_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(pr_buf, "[HEAD: " .. head_branch .. "] ")
	vim.api.nvim_buf_set_lines(pr_buf, 0, -1, false, vim.split(file_contents[2], "\n"))
	pr_state.set("buffers.pr_buf", pr_buf)

	vim.cmd("split")
	vim.cmd("resize 80%")
	local base_win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(0, base_buf)
	vim.cmd("diffthis")

	vim.cmd("rightbelow split")
	local pr_win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(0, pr_buf)
	vim.cmd("diffthis")

	vim.api.nvim_set_current_win(pr_win)

	vim.api.nvim_buf_set_keymap(pr_buf, 'n', 'q', '', {
		noremap = true,
		silent = true,
		callback = function()
			if base_win and vim.api.nvim_win_is_valid(base_win) then
				vim.api.nvim_win_close(base_win, true)
				vim.api.nvim_buf_delete(base_buf, { force = true })
			end
			if pr_win and vim.api.nvim_win_is_valid(pr_win) then
				vim.api.nvim_win_close(pr_win, true)
				vim.api.nvim_buf_delete(pr_buf, { force = true })
			end
		end
	})

	local pr_number = pr_state.get("pr_number")
	if pr_number then
		github_handler.get_pr_comments(pr_number, function(comments)
			vim.schedule(function()
				local comments_handler = require("pr-notifier.comments-handler")
				local organized_comments = comments_handler.organize_comments_by_file(comments)

				pr_state.set("organized_comments", organized_comments)

				M.display_comments_for_file(selected_file.filename)
			end)
		end)
	else
		vim.notify("No PR number found", vim.log.levels.ERROR)
	end


	vim.api.nvim_buf_set_keymap(pr_buf, 'n', '<leader>co',
		':lua require("pr-notifier.pr-display").add_comment_at_current_line()<CR>',
		{ noremap = true, silent = true })

	-- Set up keymaps
	vim.api.nvim_buf_set_keymap(pr_buf, 'n', '<BS>',
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
	local pr_data = pr_state.get("buffers.pr_buf")

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
			local pending_comments_table = pr_state.get("pending_comments")
			if not pending_comments_table then
				pending_comments_table = {}
			end

			local pending_comment = {
				path = pr_state.get("selected_file"),
				line = line_num,
				body = table.concat(vim.api.nvim_buf_get_lines(comment_buf, 0, -1, false), "\n"),
			}
			table.insert(pending_comments_table, pending_comment)
			pr_state.set("pending_comments", pending_comments_table)

			-- Close the comment window
			vim.api.nvim_win_close(win, true)

			vim.notify("Comment added to pending review: " .. vim.inspect(pending_comments_table), vim.log.levels.INFO)
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
	local buf = pr_state.get("buffers.pr_buf")

	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		vim.notify("pf_buf is not valid.", vim.log.levels.ERROR)
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

	-- comment highlight colors
	vim.api.nvim_set_hl(0, "CommentDivider", { fg = "#aaaaaa", bg = "NONE", italic = true })
	vim.api.nvim_set_hl(0, "CommentHighlight", { fg = "#dddddd", bg = "#333333", italic = false })
	local max_width = vim.api.nvim_win_get_width(0) - 10

	-- For each line with comments
	for line_num, comments in pairs(file_comments) do
		local virt_comment_lines = {}
		-- For each comment on this line

		table.insert(virt_comment_lines, { { " --- COMMENT THREAD ---", "CommentDivider" } })
		for i, comment in ipairs(comments) do
			local wrapped_text = wrap_text(" 💬 " .. comment.body, max_width)
			for _, wrapped_line in ipairs(wrapped_text) do
				table.insert(virt_comment_lines, { { wrapped_line, "CommentHighlight" } })
			end

			local comment_data = pr_state.get("comment_data")
			if not comment_data then
				pr_state.set("comment_data", {})
			end

			comment_data[comment.id or i] = {
				user = comment.user,
				body = comment.body,
				line = line_num,
				created_at = comment.created_at,
			}

			pr_state.set("comment_data", comment_data)
		end

		vim.api.nvim_buf_set_extmark(buf, ns_id, line_num, 0, {
			virt_lines = virt_comment_lines,
			virt_lines_above = false,
			priority = 100,
		})
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
		local comment_id = extmark[1] -- sign_id should be in this position

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
				row = line,                              -- Position at the commented line
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
