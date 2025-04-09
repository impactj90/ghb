local M = {}

local tmux_helper = require("pr-notifier.tmux-helper")

function M.handle_pr_selection(current_selection, owner, repo)
	local line = vim.api.nvim_buf_get_lines(0, current_selection, current_selection + 1, false)[1]
	print("line: " .. line)
	local pr_number = tonumber(line:match("^(%d+)%s*|"))
	print("pr_number: " .. pr_number)

	if not pr_number then
		vim.notify("Invalid PR number", vim.log.levels.ERROR)
		return
	end

	if not tmux_helper.is_in_tmux() then
		vim.notify("Not in tmux, cannot create new window", vim.log.levels.ERROR)
		return
	end

	-- nvim plugins tend to have rece conditions where we have to make each command explicit therefore call them separately
	-- Create a basic command that will load nvim first, then execute the lua command
	local command = "nvim"
	tmux_helper.tmux_new_window_with_command("pr-" .. pr_number, command)

	-- Wait a moment for nvim to initialize, then send the command
	vim.defer_fn(function()
		local window = tmux_helper.tmux_command("display-message -p '#{window_index}'"):gsub("\n", "")
		tmux_helper.tmux_command(
			string.format(
				[[send-keys -t %s ":lua require('pr-notifier.pr-display').show_pr_details(%d, '%s', '%s')" C-m]],
				window,
				pr_number,
				owner,
				repo
			)
		)
	end, 0)
end

return M
