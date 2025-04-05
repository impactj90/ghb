local M = {}

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

local curl = require("plenary.curl")

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

	M.setup_search_field(buf)

	vim.api.nvim_buf_set_lines(buf, 2, -1, false, { "Loading Prs..." })

	M.setup_search_handler(buf)
	M.activate_search_field(win)
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
					M.display_prs(data)
				else
					print("Failed to decode JSON response")
				end
			else
				print("error fetching prs " .. response.status)
			end
		end,
	})
end

function M.display_prs(prs)
	vim.schedule(function()
		M.all_prs = prs

		local current_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
		local search_text = current_line:match("Search:%s*(.*)")

		M.filter_and_display_prs(search_text or "")
	end)
end

function M.update_pr_display(prs)
	local buf = vim.api.nvim_get_current_buf()
	local lines = {}

	if #prs == 0 then
		table.insert(lines, "No matching PRs found")
	else
		for _, pr in ipairs(prs) do
			local draft_status = pr.draft and "[DRAFT] " or ""
			local line = string.format("%d | %s%s (%s)", pr.number, draft_status, pr.title, pr.user.login)
			table.insert(lines, line)
		end
	end

	vim.api.nvim_buf_set_lines(buf, 2, -1, false, lines)
end

--- @param buf any
function M.setup_search_field(buf)
	vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "Search: " })

	local ns_id = vim.api.nvim_create_namespace("pr_notifier_highlights")
	vim.api.nvim_buf_add_highlight(buf, ns_id, "Title", 0, 0, 7)

	vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "___________________________________________________" })
	vim.api.nvim_buf_add_highlight(buf, ns_id, "Comment", 1, 0, -1)
end

function M.activate_search_field(win)
	-- Move cursor to the end of the "Search: " text
	vim.api.nvim_win_set_cursor(win, { 1, 8 }) -- row 1, col 8 (after "Search: ")

	-- Enter insert mode immediately
	vim.cmd("startinsert")
end

function M.setup_search_handler(buf)
	local augroup = vim.api.nvim_create_augroup("PRNotifierSearch", { clear = true })

	vim.api.nvim_create_autocmd("TextChangedI", {
		buffer = buf,
		group = augroup,
		callback = function()
			-- get current search text
			local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
			local search_text = line:match("Search:%s*(.*)")

			M.filter_and_display_prs(search_text)
		end,
	})
end

function M.filter_and_display_prs(search_term)
	if not M.all_prs then
		return
	end

	local filtered_prs = {}

	if not search_term or search_term == "" then
		filtered_prs = M.all_prs
	else
		for _, pr in ipairs(M.all_prs) do
			if pr.user.login:lower():find(search_term:lower()) then
				table.insert(filtered_prs, pr)
			end
		end
	end

	M.update_pr_display(filtered_prs)
end

function M.open_pr_browser()
	if not M.validate_config() then
		return
	end

	M.open_float_window()

	M.get_prs_for_repo(M.config.owner, M.config.repo)
end

return M
