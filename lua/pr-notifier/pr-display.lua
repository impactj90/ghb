local M = {}

local github_handler = require("pr-notifier.github-handler")

function M.setup() end

function M.show_pr_details(pr_number, owner, repo)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(buf)

	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "modifiable", true)

	github_handler.get_prs_details(pr_number, function(pr_data)
		vim.schedule(function()
			local lines = {}
			table.insert(lines, "PR #" .. pr_data.number .. ": " .. pr_data.title)
			table.insert(lines, string.rep("-", vim.api.nvim_win_get_width(0) - 1)) -- Separator line
			table.insert(lines, "Author: " .. pr_data.user.login)
			table.insert(lines, "Status: " .. (pr_data.draft and "DRAFT" or pr_data.state))
			table.insert(lines, "Created: " .. pr_data.created_at:sub(1, 10))
			table.insert(lines, "")

			-- Set the lines in the buffer
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

			github_handler.get_prs_files(pr_number, function(files_data)
				vim.schedule(function()
					local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

					local new_lines = {}

					for _, line in ipairs(current_lines) do
						table.insert(new_lines, line)
					end

					table.insert(new_lines, "Files Changed (" .. #files_data .. "):")
					table.insert(new_lines, string.rep("-", vim.api.nvim_win_get_width(0) - 1)) -- Separator line

					-- Sort files by path
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
					vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)

					-- Set up file selection keymap
					vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>',
						':lua require("pr-notifier.pr-display").handle_file_selection()<CR>',
						{ noremap = true, silent = true })

					-- IMPORTANT: Store data as a global variable first as a fallback
					-- This ensures the data is available even if the buffer variables don't work
					_G.PR_REVIEW_DATA = {
						pr_number = pr_number,
						owner = owner,
						repo = repo,
						files = files_data,
					}

					-- Now try to store in buffer local variables
					vim.api.nvim_buf_set_var(buf, "pr_data", {
						pr_number = pr_number,
						owner = owner,
						repo = repo,
						files = files_data,
					})

					-- Print confirmation
					vim.notify("Stored data for " .. #files_data .. " files", vim.log.levels.INFO)
					table.insert(new_lines,
						"Press <Enter> on a file to view diff | q to close and return")
				end)
			end)
		end)
	end)


	vim.api.nvim_buf_set_keymap(buf, "n", "q", ":q<CR>", { noremap = true, silent = true })
end

function M.handle_file_selection()
	local buf = vim.api.nvim_get_current_buf()

	local bufdata = nil
	local ok = pcall(function()
		bufdata = vim.api.nvim_buf_get_var(buf, "pr_data")
	end)

	if not ok or not bufdata then
		vim.notify("Buffer data: " .. vim.inspect(bufdata), vim.log.levels.INFO)
		bufdata = _G.PR_REVIEW_DATA
		vim.notify("Using fallback global data", vim.log.levels.INFO)
	end

	if not bufdata or not bufdata.files or #bufdata.files == 0 then
		vim.notify("No file data available", vim.log.levels.ERROR)
		return
	end

	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

	local current_line = vim.api.nvim_buf_get_lines(buf, cursor_line - 1, cursor_line, false)[1]

	if not current_line:match("^%d+%. %[") then
		vim.notify("Not a file entry line: " .. current_line, vim.log.levels.WARN)
		return
	end

	local file_num = tonumber(current_line:match("^(%d+)%."))
	if not file_num then
		vim.notify("Could not extract file number from line", vim.log.levels.ERROR)
		return
	end

	if file_num > 0 and file_num <= #bufdata.files then
		local file = bufdata.files[file_num]
		vim.notify("Selected file: " .. file.filename, vim.log.levels.INFO)
		M.view_file_diff(file)
	else
		vim.notify("Invalid file number: " .. file_num, vim.log.levels.ERROR)
	end
end

function M.view_file_diff(file)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(buf)

	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "modifiable", true)
	vim.api.nvim_buf_set_option(buf, "filetype", "diff")

	vim.api.nvim_buf_set_lines(buf, 0, 1, false, {
		"Loading file diff for " .. file.filename .. "...",
		"",
		"Press <Backspace> to close and return to original window"
	})

	if file.patch then
		-- Generate diff header
		local diff_header = {
			"diff --git a/" .. file.filename .. " b/" .. file.filename,
			"--- a/" .. file.filename,
			"+++ b/" .. file.filename,
		}

		-- Split patch into lines
		local diff_lines = {}
		for line in file.patch:gmatch("[^\r\n]+") do
			table.insert(diff_lines, line)
		end

		-- Combine header and diff
		local lines = {}
		for _, line in ipairs(diff_header) do
			table.insert(lines, line)
		end
		for _, line in ipairs(diff_lines) do
			table.insert(lines, line)
		end

		-- Set the lines in the buffer
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	else
		-- If patch is not available (for large diffs), show a message
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
			"Patch not available for " .. file.filename,
			"This usually happens for large files.",
			"",
			"Press <Backspace> to return to PR details | q to exit to code"
		})
	end
	-- Set up keymaps
	vim.api.nvim_buf_set_keymap(buf, 'n', '<BS>',
		':q<CR>',
		{ noremap = true, silent = true })
end

return M
