local M = {
	pending_comments = {},
	current_review = nil
}

function M.add_comment(pr_number, file_path, line, body)
	-- add to pending comments
end

function M.submit_review(pr_number, event_type, body)
	-- submit all pending comments as a review
end

return M
