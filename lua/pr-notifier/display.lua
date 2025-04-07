local M = {}

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

return M
