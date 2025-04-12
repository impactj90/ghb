local M = {}

local search = require("pr-notifier.search")
local github_handler = require("pr-notifier.github-handler")

M.config = {
	owner = nil,
	repo = nil,
	token = nil,
	show_drafts = true,
	window = {
		width_pct = 0.6,
		height_pct = 0.7,
		border = "rounded",
	},
}

function M.setup(opts)
	opts = opts or {}

	for k, v in pairs(opts) do
		if k == "window" and type(v) == "table" then
			for wk, wv in pairs(v) do
				M.config.window[wk] = wv
			end
		else
			M.config[k] = v
		end
	end

	if not M.validate_config() then
		return
	end

	github_handler.setup(M.config)

	vim.api.nvim_create_user_command("Ghb", function()
		M.open_pr_browser()
	end, {})
end

--- @return boolean
function M.validate_config()
	if not M.config.owner then
		vim.notify("Github owner/organization is not set", vim.log.levels.ERROR)
		return false
	end

	if not M.config.repo then
		vim.notify("Github repository not set", vim.log.levels.Error)
		return false
	end

	if not M.config.token and not M.load_token() then
		vim.notify("Github token not set. Please configure it", vim.log.levels.Error)
		return false
	end

	return true
end

--- @return boolean
function M.load_token()
	if M.config.token ~= nil then
		return true
	end

	local token_file = vim.fn.expand("~/.config/nvim/github_token.lua")

	if vim.fn.filereadable(token_file) == 1 then
		local ok, token_data = pcall(dofile, token_file)
		if ok and type(token_data) == "table" and token_data.token then
			M.config.token = token_data.token
			return true
		end
	end

	return false
end

function M.open_float_window()
	local width_pct = M.config.window.width_pct or 0.6
	local height_pct = M.config.window.height_pct or 0.7
	local width = math.floor(vim.o.columns * width_pct)
	local height = math.floor(vim.o.lines * height_pct)

	local buf = vim.api.nvim_create_buf(false, true)

	local win_opts = {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor(((vim.o.columns - width) / 2) - 1),
		row = math.floor((vim.o.lines - height) / 2),
		style = "minimal",
		border = M.config.window.border,
	}

	local win = vim.api.nvim_open_win(buf, true, win_opts)

	search.setup_search_field(buf, M.config.owner, M.config.repo)

	vim.api.nvim_buf_set_lines(buf, 2, -1, false, { "Loading Prs..." })

	search.setup_search_handler(buf)
	search.activate_search_field(win)
end

function M.open_pr_browser()

	M.open_float_window()
	github_handler.get_prs_for_repo()
end

return M
