local M = {
	owner = nil,
	repo = nil,
	files = nil,
	selected_file = nil,
	selected_patch = nil,
	base_branch = nil,
	head_branch = nil,
	-- buffers are like containers in html
	buffers = {
		details = nil,
		file = nil,
		-- new ones after better knowledge of the nvim api
		base_buf = nil,
		pr_buf = nil,
	},
	filename = nil,
	commit_id = nil,
	pr_number = 0,
	line_mapping = nil,
	pending_comments = {},
	organized_comments = {},
	comment_data = {},
}


function M.get(path)
	if not path then
		return M
	end

	local parts = {}
	for part in string.gmatch(path, "[^%.]+") do
		table.insert(parts, part)
	end

	local current = M
	for _, part in ipairs(parts) do
		if current[part] == nil then
			return nil
		end

		current = current[part]
	end

	return current
end

function M.set(path, value)
	local parts = {}
	for part in string.gmatch(path, "[^%.]+") do
		table.insert(parts, part)
	end

	if #parts == 1 then
		M[parts[1]] = value
		return
	end

	local current = M
	for i = 1, #parts - 1 do
		local part = parts[i]
		if current[part] == nil then
			current[part] = {}
		end
		current = current[part]
	end

	current[parts[#parts]] = value
end

return M
