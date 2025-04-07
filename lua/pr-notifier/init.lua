local M = {}

local search = require("pr-notifier.search")
local display = require("pr-notifier.display")
local curl = require("plenary.curl")
local tmux_helper = require("pr-notifier.tmux-helper")

M.config = {
	owner = nil,
	repo = nil,
	token = nil,
	show_drafts = true,
	window = {
		width = 100,
		height = 50,
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

	vim.api.nvim_create_user_command("Ghb", function()
		M.open_pr_browser()
	end, {})

	vim.api.nvim_create_user_command("GhbTestWindow", function()
		if tmux_helper.is_in_tmux() then
			local window = tmux_helper.tmux_new_window("ghb-test")
			print(window)
		else
			vim.notify("Not in tmux", vim.log.levels.ERROR)
		end
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
	local buf = vim.api.nvim_create_buf(false, true)

	local win_opts = {
		relative = "editor",
		width = M.config.window.width,
		height = M.config.window.height,
		col = (vim.o.columns - M.config.window.width) / 2,
		row = (vim.o.lines - M.config.window.height) / 2,
		style = "minimal",
		border = M.config.window.border,
	}

	local win = vim.api.nvim_open_win(buf, true, win_opts)

	search.setup_search_field(buf)

	vim.api.nvim_buf_set_lines(buf, 2, -1, false, { "Loading Prs..." })

	search.setup_search_handler(buf)
	search.activate_search_field(win)
end

--- @param owner string
--- @param repo string
function M.get_prs_for_repo(owner, repo)
	curl.get({
		url = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/pulls",
		headers = {
			["User-Agent"] = "github-pr-browser-nvim",
			["Authorization"] = "token " .. M.config.token,
		},
		callback = function(response)
			if response.status == 200 then
				local success, data = pcall(vim.json.decode, response.body)
				if success then
					display.display_prs(data)
				else
					print("Failed to decode JSON response")
				end
			else
				print("error fetching prs " .. response.status)
			end
		end,
	})
end

function M.open_pr_browser()
	if not M.validate_config() then
		return
	end

	M.open_float_window()

	M.get_prs_for_repo(M.config.owner, M.config.repo)
end

return M
