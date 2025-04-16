local M = {
	pending_comments = {},
	current_review = nil
}

function M.add_comment(pr_number, file_path, line, body)
	if pr_number == nil or file_path == nil or line == nil or body == nil then
		vim.notify("Invalid parameters", vim.log.levels.ERROR)
		return
	end

	if M.current_review == nil then
		M.current_review = pr_number
	elseif M.current_review ~= pr_number then
		vim.notify("Switching PRs during review. Previous comments will be discarded", vim.log.levels.WARN)
		M.pending_comments = {}
		M.current_review = pr_number
	end

	table.insert(M.pending_comments, {
		file_path = file_path,
		position = line,
		body = body,
	})

	return #M.pending_comments
end

function M.submit_review(pr_number, event_type, body)
	-- submit all pending comments as a review
end

return M
