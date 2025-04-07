local M = {}

function M.is_in_tmux()
	return vim.env.TMUX ~= nil
end

function M.tmux_command(cmd)
	print("tmux command: " .. cmd)
	local tmuxHandler = io.popen("tmux " .. cmd)
	local result
	if tmuxHandler then
		result = tmuxHandler:read("*a")
		tmuxHandler:close()
	end
	print("result" .. result)
	return result
end

function M.tmux_new_window(name)
	M.tmux_command(string.format("new-window -n %s", name:gsub("'", "'\\'")))
	return M.tmux_command("display-message -p '#{window_index}'"):gsub("\n", "")
end

function M.tmux_send_to_window(window, keys)
	local escaped_keys = keys:gsub("'", "'\\''")
	M.tmux_command(string.format("send-keys -t %s '%s' Enter", window, escaped_keys))
end

return M
