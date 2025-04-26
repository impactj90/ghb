local M = {}

function M.organize_comments_by_file(comments)
	local organized = {}

	for _, comment in ipairs(comments) do
		local file_path = comment.path
		local line_num = comment.original_line or 0

		if not organized[file_path] then
			organized[file_path] = {}
		end

		if not organized[file_path][line_num] then
			organized[file_path][line_num] = {}
		end

		table.insert(organized[file_path][line_num], {
			body = comment.body,
			user = comment.user,
			created_at = comment.created_at,
			id = comment.id
		})
	end

	return organized
end

function M.queue_comments()
end

return M
