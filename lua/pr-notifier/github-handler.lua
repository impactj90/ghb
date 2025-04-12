local curl = require("plenary.curl")

local M = {}

M.config = nil

function M.setup(opts)
	M.config = opts
end

function M.get_prs_for_repo(callback)
	curl.get({
		url = "https://api.github.com/repos/" .. M.config.owner .. "/" .. M.config.repo .. "/pulls?per_page=100",
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
		url = "https://api.github.com/repos/" ..
		    M.config.owner .. "/" .. M.config.repo .. "/pulls/" .. pr_number .. "/files",
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

function M.create_comment(pr_number, body, callback)
	curl.post({
		url = "https://api.github.com/repos/" ..
		    M.config.owner .. "/" .. M.config.repo .. "/pulls/" .. pr_number .. "/comments",
		headers = {
			["User-Agent"] = "github-pr-browser-nvim",
			["Authorization"] = "token " .. M.config.token,
		},
		body = body,
		callback = function(response)
			if response.status == 201 then
				print("Comment created successfully")
			else
				print("Error creating comment: " .. response.status)
			end
		end
	})
end

return M
