# pr-notifier.nvim

🚀 A lightweight, native GitHub PR review browser, comment viewer, and reviewer for Neovim.

---

## ✨ Features

- Browse open Pull Requests from a configured GitHub repository
- View PR file diffs side-by-side with `:diffthis`
- Display inline comments visually with virtual text
- Add pending comments to specific lines
- Submit full reviews (`COMMENT`, `APPROVE`, `REQUEST_CHANGES`)
- Automatically refresh comments after submitting reviews
- Fast, minimal, written fully in Lua
- Secure GitHub authentication via local token file

---

## 📦 Installation

Install using your favorite plugin manager:

### Lazy.nvim

```lua
{
  "yourname/pr-notifier.nvim",
  config = function()
    require("pr-notifier").setup({
      owner = "your-github-username-or-org",
      repo = "your-repo-name",
      -- token is optional if you use the github_token.lua file (see below)
    })
  end
}
use {
  "yourname/pr-notifier.nvim",
  config = function()
    require("pr-notifier").setup({
      owner = "your-github-username-or-org",
      repo = "your-repo-name",
      -- token is optional if you use the github_token.lua file (see below)
    })
  end
}
```

## 🔐 GitHub Authentication (Full Setup)

pr-notifier.nvim requires a GitHub Personal Access Token (PAT)
to interact with the GitHub API (view PRs, add comments, submit reviews).

Step 1: Create a GitHub Personal Access Token (PAT)
Go to GitHub → Settings → Developer Settings → Personal Access Tokens

Generate a new token with the repo scope (at minimum).

Copy your token safely.

Step 2: Create a Local Token File
Create a token file at:

mkdir -p ~/.config/nvim/
touch ~/.config/nvim/github_token.lua

return {
  token = "your-personal-access-token-here",
}

✅ The plugin will automatically detect and load this token at startup.
✅ You don't need to hardcode your token inside init.lua — safer for dotfiles!

## 🚀 Usage

After opening a PR diff view:


Keybinding	Action
<leader>co	Add a pending comment at the current line
<leader>sr	Submit a review (after selecting type)
<leader>cr	Show detailed comment info at current line
(These keymaps are buffer-local to PR diff buffers.)

## 🔧 Configuration Options
```lua
{
  owner = "your-github-username-or-org", -- required
  repo = "your-repo-name",               -- required
  token = "your-github-token",            -- optional if using github_token.lua
}
```

## 🛠 Requirements

Neovim >= 0.8

plenary.nvim

## ❓ Troubleshooting

401 Unauthorized?

Check that your GitHub token is correct and has the correct scopes.

Verify that your github_token.lua file exists, is formatted correctly, and is readable.

Comments not appearing immediately?

After submitting a review, the plugin automatically reloads and displays updated comments.

Make sure your comments are added to changed lines (not unchanged context lines).

## 🎯 Roadmap / TODO
 
 Inline commenting and reviews

 Full review (COMMENT, APPROVE, REQUEST_CHANGES)

 Reaction support (thumbs up, rocket, etc.)

 Telescope integration for PR browsing

 Dynamic configuration for multiple repositories

 Customizable keybindings

## 💬 Contributing

Contributions, ideas, and pull requests are very welcome!
Feel free to open an issue or PR if you have suggestions, bug fixes, or features in mind.

## 📜 License

MIT License.
See LICENSE for more information.

## ❤️ Credits

Inspired by:

octo.nvim

gh.nvim

Big thanks to the Neovim and GitHub open-source community!
