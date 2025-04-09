local M = {}

function M.setup() end

function M.show_pr_details(pr_number, owner, repo)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(buf)

	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "modifiable", true)

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
		"PR #" .. pr_number .. " Details",
		"Owner: " .. owner,
		"Repo: " .. repo,
		"",
		"This is a test. In the real implementation, we would fetch PR details here.",
		"",
		"Press q to close",
	})

	vim.api.nvim_buf_set_keymap(buf, "n", "q", ":q<CR>", { noremap = true, silent = true })
end

return M
