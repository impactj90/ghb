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

function M.get_review_comments(pr_number, callback)
	curl.get({
		url = "https://api.github.com/repos/" ..
		    M.config.owner .. "/" .. M.config.repo .. "/pulls/" .. pr_number .. "/comments",
		headers = {
			["User-Agent"] = "github-pr-browser-nvim",
			["Authorization"] = "token " .. M.config.token,
		},
		callback = function(response)
			if response.status == 200 then
				local success, data = pcall(vim.json.decode, response.body)
				if success then
					callback(data)
				end
			else
				print("Error creating comment: " .. response.status)
			end
		end
	})
end

function M.create_review_comment(pr_number, commit_id, path, position, body, callback)
	local request_body = vim.json.encode({
		commit_id = commit_id,
		path = path,
		position = position,
		body = body,
	})

	curl.post({
		url = "https://api.github.com/repos/" ..
		    M.config.owner .. "/" .. M.config.repo .. "/pulls/" .. pr_number .. "/comments",
		headers = {
			["User-Agent"] = "github-pr-browser-nvim",
			["Authorization"] = "token " .. M.config.token,
			["Content-Type"] = "application/json",
		},
		body = request_body,
		callback = function(response)
			if response.status == 201 then
				local success, data = pcall(vim.json.decode, response.body)
				if success then
					callback(data)
				end
			else
				print("Error creating comment: " .. response.status)
			end
		end
	})
end

function M.submit_review(pr_number, event_type, body, comments, callback)
	local request_body = vim.json.encode({
		event = event_type,
		body = body,
		comments = comments or {},
	})
	-- review_data should contain event (APPROVE, REQUEST_CHANGES, COMMENT) and body
	curl.post({
		url = "https://api.github.com/repos/" ..
		    M.config.owner .. "/" .. M.config.repo .. "/pulls/" .. pr_number .. "/reviews",
		headers = {
			["User-Agent"] = "github-pr-browser-nvim",
			["Authorization"] = "token " .. M.config.token,
			["Content-Type"] = "application/json",
		},
		body = request_body,
		callback = function(response)
			if response.status == 201 then
				callback(response.body)
			else
				print("Error creating comment: " .. response.status)
			end
		end
	})
end

function M.get_pr_comments(pr_number, callback)
	curl.get({
		url = "https://api.github.com/repos/" ..
		    M.config.owner .. "/" .. M.config.repo .. "/pulls/" .. pr_number .. "/comments",
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
					print("Failed to decode JSON response for comments")
				end
			else
				print("Error fetching PR comments: " .. response.status)
			end
		end,
	})
end

function M.get_pr_issue_comments(pr_number, callback)
	curl.get({
		url = "https://api.github.com/repos/" ..
		M.config.owner .. "/" .. M.config.repo .. "/issues/" .. pr_number .. "/comments",
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
					print("Failed to decode JSON response for comments")
				end
			else
				print("Error fetching PR comments: " .. response.status)
			end
		end,
	})
end

return M
