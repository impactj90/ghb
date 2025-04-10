local M = {}

local curl = require("plenary.curl")
local display = require("pr-notifier.display")

M.config = nil

function M.setup(opts)
	M.config = opts
end

function M.get_prs_for_repo()
	curl.get({
		url = "https://api.github.com/repos/" .. M.config.owner .. "/" .. M.config.repo .. "/pulls",
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

function M.get_prs_details(pr_number, callback)
	curl.get({
		url = "https://api.github.com/repos/" .. M.config.owner .. "/" .. M.config.repo .. "/pulls/" .. pr_number,
		headers = {
			["User-Agent"] = "github-pr-browser-nvim",
			["Authorization"] = "token " .. M.config.token,
		},
		callback = function(response)
			if response.status == 200 then
				local success, data = pcall(vim.json.decode, response.body)
				if success then
					callback(data)
				else
					print("Failed to decode JSON response")
				end
			else
				print("error fetching prs " .. response.status)
			end
		end,
	})
end


function M.get_prs_files(pr_number, callback)
	curl.get({
		url = "https://api.github.com/repos/" .. M.config.owner .. "/" .. M.config.repo .. "/pulls/" .. pr_number .. "/files",
		headers = {
			["User-Agent"] = "github-pr-browser-nvim",
			["Authorization"] = "token " .. M.config.token,
		},
		callback = function(response)
			if response.status == 200 then
				local success, data = pcall(vim.json.decode, response.body)
				if success then
					callback(data)
				else
					print("Failed to decode JSON response")
				end
			else
				print("error fetching prs " .. response.status)
			end
		end,
	})
end

return M
