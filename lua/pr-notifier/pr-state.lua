local M = {
	owner = nil,
	repo = nil,
	files = nil,
	selected_file = nil,
	-- buffers are like containers in html
	buffers = {
		details = nil,
		file_diff = nil,
	},
	filename = nil,
	commit_id = nil,
	pr_number = nil,
	line_mapping = nil,
	pending_comments = {}
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

	local current = M
	for i = 1, #parts - 1 do
		if current[parts[i]] == nil then
			current[parts[i]] = {}
		end
		current[parts[#parts]] = value
	end
end

return M
