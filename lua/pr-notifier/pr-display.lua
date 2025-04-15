local github_handler = require("pr-notifier.github-handler")
local pr_preview = require("pr-notifier.pr-preview")
local pr_state = require("pr-notifier.pr-state")

local M = {
	details_buf = nil,
	file_buf = nil,
}

function M.setup() end

function M.show_pr_details(pr_number, owner, repo)
	M.details_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(M.details_buf)

	vim.api.nvim_buf_set_option(M.details_buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(M.details_buf, "swapfile", false)
	vim.api.nvim_buf_set_option(M.details_buf, "modifiable", true)

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

					-- Add blank line and help text
					table.insert(new_lines, "")

					-- Update buffer
					vim.api.nvim_buf_set_lines(M.details_buf, 0, -1, false, new_lines)

					-- Set up file selection keymap
					vim.api.nvim_buf_set_keymap(M.details_buf, 'n', '<CR>',
						':lua require("pr-notifier.pr-display").handle_file_selection()<CR>',
						{ noremap = true, silent = true })

					pr_state.set("pr_number", pr_number)
					pr_state.set("owner", owner)
					pr_state.set("repo", repo)
					pr_state.set("files", files_data)

					-- Print confirmation
					vim.notify("Stored data for " .. #files_data .. " files", vim.log.levels.INFO)
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
		vim.notify("No files selected", vim.log.levels.ERROR)
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

	vim.api.nvim_buf_set_keymap(M.file_buf, 'n', '<Space>co',
		':lua require("pr-notifier.pr-display").handle_add_comment_keypress()<CR>',
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

function M.handle_add_comment_keypress()
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	local line_mapping = pr_state.get("line_mapping")

	if not cursor_line then
		vim.notify("No cursor line was recorded", vim.log.levels.ERROR)
		return
	end
	local diff_position = line_mapping[cursor_line]

	local filename = pr_state.get("filename")
	local pr_number = pr_state.get("pr_number")

	vim.ui.input({ prompt = "Add comment: " }, function(input)
		if input and input ~= "" then
			pr_preview.add_comment(pr_number, filename, diff_position, input)

			M.refresh_ui_with_comments(pr_number, filename, diff_position, input)
		end
	end)
end

function M.refresh_ui_with_comments(pr_number, file_path, diff_position, input)
	vim.inspect(pr_number)
	vim.inspect(file_path)
	vim.inspect(diff_position)
	vim.inspect(input)
	-- M.show_comments()
end

function M.show_comments(cursor_line)
	print("Showing comments")
end

return M
