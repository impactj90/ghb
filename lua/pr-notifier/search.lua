local M = {}

local display = require("pr-notifier.display")
local ns_id = vim.api.nvim_create_namespace("pr_notifier_highlights")

--- @param buf any
function M.setup_search_field(buf)
	vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "Search: " })

	vim.api.nvim_buf_add_highlight(buf, ns_id, "Title", 0, 0, 7)
	vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "" })
end

function M.activate_search_field(win)
	-- Move cursor to the end of the "Search: " text
	vim.api.nvim_win_set_cursor(win, { 1, 8 }) -- row 1, col 8 (after "Search: ")
end

function M.setup_search_handler(buf)
	local augroup = vim.api.nvim_create_augroup("PRNotifierSearch", { clear = true })

	vim.api.nvim_create_autocmd("TextChangedI", {
		buffer = buf,
		group = augroup,
		callback = function()
			local search_line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
			local search_text = search_line:match("Search:%s*(.*)")

			display.filter_and_display_prs(search_text)

			vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

			local line_count = vim.api.nvim_buf_line_count(buf)

			for i = 2, line_count - 1 do
				local pr_first_line_count = vim.api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
				local start_pos, end_pos = M.find_username(pr_first_line_count)
				if start_pos and end_pos then
					vim.api.nvim_buf_add_highlight(buf, ns_id, "CursorLine", i, start_pos - 1, end_pos)
				end
			end
		end,
	})
end

function M.find_username(line)
	local startPos = line:find("%(")
	local endPos = line:find("%)")

	if startPos and endPos then
		return startPos + 1, endPos - 1
	end

	return nil, nil
end

return M
