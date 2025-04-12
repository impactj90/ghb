local M = {}

local github_handler = require("pr-notifier.github-handler")
local telescope_integration = require("pr-notifier.telescope")

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
		local has_telescope, telescope = pcall(require, "telescope")
		if not has_telescope then
			vim.notify("Telescope.nvim is required for this command", vim.log.levels.ERROR)
			return
		end

		telescope_integration.browse_prs()
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

return M
