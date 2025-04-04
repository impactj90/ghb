local M = {}

function M.setup(opts)
	opts = opts or {}

	vim.api.nvim_create_user_command("Ghb", function()
		M.open_pr_browser()
	end, {})
end

function M.open_pr_browser()
	M.open_float_window()
end

function M.open_float_window()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Hello World", "Hello Me!" })

	local width = 200
	local height = 50
	local win_opts = {
		relative = "editor",
		width = width,
		height = height,
		col = (vim.o.columns - width) / 2,
		row = (vim.o.lines - height) / 2,
		style = "minimal",
		border = "rounded",
	}

	local win = vim.api.nvim_open_win(buf, true, win_opts)
end

return M
