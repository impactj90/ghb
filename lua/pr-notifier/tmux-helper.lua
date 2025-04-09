local M = {}

function M.is_in_tmux()
	return vim.env.TMUX ~= nil
end

function M.tmux_command(cmd)
	local tmuxHandler = io.popen("tmux " .. cmd)
	local result
	if tmuxHandler then
		result = tmuxHandler:read("*a")
		tmuxHandler:close()
	end
	return result
end

function M.tmux_send_to_window(window, keys)
	local escaped_keys = keys:gsub("'", "'\\''")
	M.tmux_command(string.format("send-keys -t %s '%s' Enter", window, escaped_keys))
	vim.cmd("redraw!") -- Force Neovim to redraw after tmux command
end

function M.tmux_new_window(name)
	M.tmux_command(string.format("new-window -n %s", name:gsub("'", "'\\'")))
	local window = M.tmux_command("display-message -p '#{window_index}'"):gsub("\n", "")
	vim.cmd("redraw!") -- Force Neovim to redraw after window creation
	return window
end

function M.tmux_select_window(window)
	M.tmux_command("select-window -t " .. window)
end

function M.tmux_new_window_with_command(name, command)
	local escaped_name = name:gsub("'", "'\\''")
	local escaped_command = command:gsub("'", "'\\''")
	M.tmux_command(string.format('new-window -n %s "%s"', escaped_name, escaped_command))
	local window = M.tmux_command("display-message -p '#{window_index}'"):gsub("\n", "")
	vim.cmd("redraw!")
	return window
end

return M
