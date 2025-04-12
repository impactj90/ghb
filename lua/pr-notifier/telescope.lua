local pr_selector_handler = require("pr-notifier.pr-selector-handler")

local M = {}

function M.browse_prs()
	-- Check if Telescope is available
	local has_telescope, _ = pcall(require, "telescope")
	if not has_telescope then
		vim.notify("Telescope.nvim is required for this feature", vim.log.levels.ERROR)
		return
	end

	-- Load Telescope's dependencies
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	local github_handler = require("pr-notifier.github-handler")
	local pr_display = require("pr-notifier.pr-display")

	-- Create a dummy finder for initial display
	local initial_results = { { value = nil, display = "Loading PRs...", ordinal = "" } }

	-- Create the picker
	local picker = pickers.new({}, {
		prompt_title = "GitHub Pull Requests",
		finder = finders.new_table({
			results = initial_results,
			entry_maker = function(entry)
				return {
					value = entry.value,
					display = entry.display,
					ordinal = entry.ordinal or "",
				}
			end
		}),
		sorter = conf.generic_sorter({}),
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				if not selection or not selection.value then return end

				actions.close(prompt_bufnr)
				pr_selector_handler.handle_pr_selection(selection.value.number,
					github_handler.config.owner, github_handler.config.repo)
			end)
			return true
		end,
	})

	-- Launch the picker immediately with the "Loading" message
	picker:find()

	-- Fetch actual PR data
	github_handler.get_prs_for_repo(function(prs)
		if not prs or #prs == 0 then
			-- Update the picker with "No PRs found" message
			local new_finder = finders.new_table({
				results = { { value = nil, display = "No PRs found", ordinal = "" } },
				entry_maker = function(entry)
					return {
						value = entry.value,
						display = entry.display,
						ordinal = entry.ordinal or "",
					}
				end
			})
			picker:refresh(new_finder, { reset_prompt = false })
			return
		end

		-- Format PR data for display
		local results = {}
		for _, pr in ipairs(prs) do
			local draft_status = pr.draft and "[DRAFT] " or ""
			table.insert(results, {
				value = pr,
				display = pr.number .. " | " .. draft_status .. pr.title .. " (" .. pr.user.login .. ")",
				ordinal = pr.number .. " " .. pr.title .. " " .. pr.user.login,
			})
		end

		-- Update the picker with the PR data
		local new_finder = finders.new_table({
			results = results,
			entry_maker = function(entry)
				return {
					value = entry.value,
					display = entry.display,
					ordinal = entry.ordinal or "",
				}
			end
		})

		picker:refresh(new_finder, { reset_prompt = false })
	end)
end

return M
