-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Example configs: https://github.com/LunarVim/starter.lvim
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny
--[[
 THESE ARE EXAMPLE CONFIGS FEEL FREE TO CHANGE TO WHATEVER YOU WANT
 `lvim` is the global options object
]]
-- -- Change theme settings
-- lvim.colorscheme = "lunar"
-- lvim.colorscheme = "nord"
lvim.colorscheme = "onenord"
-- lvim.colorscheme = "onedark"
-- lvim.colorscheme = "tokyonight-storm"
-- lvim.colorscheme = "catppuccin-mocha"
-- lvim.colorscheme = "catppuccin-macchiato"

-- vim options
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.relativenumber = false
vim.opt.expandtab

-- general
-- lvim.log.level = "info"
lvim.log.level = "off"
lvim.format_on_save = {
  enabled = true,
  pattern = "*.lua",
  timeout = 1000,
}
-- to disable icons and use a minimalist setup, uncomment the following
-- lvim.use_icons = false

-- keymappings <https://www.lunarvim.org/docs/configuration/keybindings>
lvim.leader = "space"
-- add your own keymapping
lvim.keys.normal_mode["<C-s>"] = ":w<cr>"
vim.diagnostic.config({ virtual_text = false })

----------- My key mappings for nVimTree, Buffer, File functions-------------------------------------
local opts = { noremap = true, silent = true }
local map = vim.api.nvim_set_keymap

-- NvimTree
map("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", opts)
map("n", "<A-e>", ":NvimTreeFocus<CR>", opts)

-- Navigate buffers
map("n", "<A-,>", "<cmd>bnext<CR>", opts)
map("n", "<A-.>", "<cmd>bprevious<CR>", opts)

-- ForceWrite
map("n", "<C-s>", "<cmd>w!<CR>", opts)
-- ForceQuit
map("n", "<C-q>", "<cmd>q!<CR>", opts)
-- Terminal
map("n", "<A-t>", "<cmd>ToggleTerm<CR>", opts)

-- -----------------VS Code like cusror movements selection and copy paste----------------------------
local map = function(mode, key, command)
  vim.api.nvim_set_keymap(mode, key, command, {
    noremap = true,
    silent = true
  })
end

function CopyCurrentLineToClipboard()
  local ft = vim.bo.filetype
  if ft == "NvimTree" then
    require "nvim-tree".on_keypress("copy_absolute_path")
  else
    vim.cmd("normal ^\"+y$")
  end
end

local nnoremap = function(options)
  -- trigger key
  local key = options[1] or options.key
  -- command
  local command = options[2] or options.command

  -- noremap is true by default
  local noremap = options.noremap
  if noremap == nil then noremap = true end

  -- silent is true by default
  local silent = options.silent
  if silent == nil then silent = true end

  -- expr is false by default
  local expr = options.expr
  if expr == nil then expr = false end

  vim.api.nvim_set_keymap("n", key, command, { noremap = noremap, silent = silent, expr = expr })
end


-- inoremap function
local inoremap = function(options)
  -- trigger key
  local key = options[1] or options.key
  -- command
  local command = options[2] or options.command
  -- noremap is true by default
  local noremap = options.noremap or true
  -- silent is true by default
  local silent = options.silent or true
  -- expr is false by default
  local expr = options.expr or false

  vim.api.nvim_set_keymap("i", key, command, { noremap = noremap, silent = silent, expr = expr })
end


-- vnoremap function (visual mode)
local vnoremap = function(options)
  -- trigger key
  local key = options[1] or options.key
  -- command
  local command = options[2] or options.command
  -- noremap is true by default
  local noremap = options.noremap or true
  -- silent is true by default
  local silent = options.silent or true
  -- expr is false by default
  local expr = options.expr or false

  vim.api.nvim_set_keymap("v", key, command, { noremap = noremap, silent = silent, expr = expr })
end

--> text selection with shift + left/right just like vs code
-- left
nnoremap { "<S-left>", "v<left>" }
inoremap { "<S-left>", "<esc>v<left>" }
vnoremap { "<S-left>", "<left>" }
-- right
nnoremap { "<S-right>", "v<right>" }
inoremap { "<S-right>", "<c-o><right><esc>v<right>" }
vnoremap { "<S-right>", "<right>" }


--> Selection Up and Down --
-- trigger visual line from insert mode
map("i", "<S-up>", "<c-o><S-v>k")
map("i", "<S-down>", "<c-o><S-v>j")
map("v", "<S-up>", "<up>")
map("v", "<S-down>", "<down>")
-- trigger visual line from normal mode using shift
map("n", "<S-up>", "<S-v>k")
map("n", "<S-down>", "<S-v>j")


--> copy paste like vs code
-- trigger visual line from insert mode
map("n", "<C-c>", ":lua CopyCurrentLineToClipboard()<CR>")
map("i", "<C-c>", "<C-o>:lua CopyCurrentLineToClipboard()<CR>")
-- trigger visual line from normal mode
map("v", "<C-c>", "\"+ygv")


--> undo redo in lua just like vs code
-- undo for insert mode
map("n", "<C-z>", "u", noremap_silent)
map("i", "<C-z>", "<C-o>u", noremap_silent)
map("v", "<C-z>", "<esc>u", noremap_silent)
-- redo for normal mode is built-in
map("i", "<C-r>", "<C-o><C-r>", noremap_silent)
map("v", "<C-r>", "<esc><C-r>", noremap_silent)

--> navigation like vscode
-- go back
map("n", "<A-Left>", "<c-o>")
map("i", "<A-Left>", "<c-o><c-o>")
-- go forward
map("n", "<A-Right>", "<c-i>")
map("i", "<A-Right>", "<c-o><c-i>")
-- lvim.keys.normal_mode["<S-l>"] = ":BufferLineCycleNext<CR>"
-- lvim.keys.normal_mode["<S-h>"] = ":BufferLineCyclePrev<CR>"

-- -- Use which-key to add extra bindings with the leader-key prefix
-- lvim.builtin.which_key.mappings["W"] = { "<cmd>noautocmd w<cr>", "Save without formatting" }
-- lvim.builtin.which_key.mappings["P"] = { "<cmd>Telescope projects<CR>", "Projects" }


-- -- Change theme settings
-- lvim.colorscheme = "onedarker"
-- lvim.colorscheme = "lunar"

lvim.builtin.alpha.active = true
lvim.builtin.alpha.mode = "dashboard"
lvim.builtin.terminal.active = true
lvim.builtin.nvimtree.setup.view.side = "left"
lvim.builtin.nvimtree.setup.renderer.icons.show.git = false

-- Automatically install missing parsers when entering buffer
lvim.builtin.treesitter.auto_install = true

-- lvim.builtin.treesitter.ignore_install = { "haskell" }

-- -- always installed on startup, useful for parsers without a strict filetype
-- lvim.builtin.treesitter.ensure_installed = { "comment", "markdown_inline", "regex" }

-- -- generic LSP settings <https://www.lunarvim.org/docs/languages#lsp-support>

-- --- disable automatic installation of servers
-- lvim.lsp.installer.setup.automatic_installation = false

-- ---configure a server manually. IMPORTANT: Requires `:LvimCacheReset` to take effect
-- ---see the full default list `:lua =lvim.lsp.automatic_configuration.skipped_servers`
-- vim.list_extend(lvim.lsp.automatic_configuration.skipped_servers, { "pyright" })
-- local opts = {} -- check the lspconfig documentation for a list of all possible options
-- require("lvim.lsp.manager").setup("pyright", opts)

-- ---remove a server from the skipped list, e.g. eslint, or emmet_ls. IMPORTANT: Requires `:LvimCacheReset` to take effect
-- ---`:LvimInfo` lists which server(s) are skipped for the current filetype
-- lvim.lsp.automatic_configuration.skipped_servers = vim.tbl_filter(function(server)
--   return server ~= "emmet_ls"
-- end, lvim.lsp.automatic_configuration.skipped_servers)

-- -- you can set a custom on_attach function that will be used for all the language servers
-- -- See <https://github.com/neovim/nvim-lspconfig#keybindings-and-completion>
-- lvim.lsp.on_attach_callback = function(client, bufnr)
--   local function buf_set_option(...)
--     vim.api.nvim_buf_set_option(bufnr, ...)
--   end
--   --Enable completion triggered by <c-x><c-o>
--   buf_set_option("omnifunc", "v:lua.vim.lsp.omnifunc")
-- end

-- -- linters, formatters and code actions <https://www.lunarvim.org/docs/languages#lintingformatting>
-- local formatters = require "lvim.lsp.null-ls.formatters"
-- formatters.setup {
--   { command = "stylua" },
--   {
--     command = "prettier",
--     extra_args = { "--print-width", "100" },
--     filetypes = { "typescript", "typescriptreact" },
--   },
-- }
-- local linters = require "lvim.lsp.null-ls.linters"
-- linters.setup {
--   { command = "flake8", filetypes = { "python" } },
--   {
--     command = "shellcheck",
--     args = { "--severity", "warning" },
--   },
-- }
-- local code_actions = require "lvim.lsp.null-ls.code_actions"
-- code_actions.setup {
--   {
--     exe = "eslint",
--     filetypes = { "typescript", "typescriptreact" },
--   },
-- }

-- -- Additional Plugins <https://www.lunarvim.org/docs/plugins#user-plugins>
lvim.plugins = {
  {
    "folke/trouble.nvim",
    cmd = "TroubleToggle",
  },
  -- { "LunarVim/Colorschemes" },
  -- { "olimorris/onedarkpro.nvim" },
  { "arcticicestudio/nord-vim" },
  { "folke/tokyonight.nvim" },
  { "rmehri01/onenord.nvim" },
  { "ChristianChiarulli/onedark.nvim" },
  { "catppuccin/nvim" },
  { "ggandor/lightspeed.nvim" },
  { "romgrk/doom-one.vim" },
  --{""},
  --{""},
  --{""},
}

-- -- Autocommands (`:help autocmd`) <https://neovim.io/doc/user/autocmd.html>
-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = "zsh",
--   callback = function()
--     -- let treesitter use bash highlight for zsh files as well
--     require("nvim-treesitter.highlight").attach(0, "bash")
--   end,
-- })