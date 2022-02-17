-- local status_ok, which_key = pcall(require, "which-key")
-- if not status_ok then
--   return
-- end
local which_key = require("which-key")

local setup = {
  plugins = {
    marks = true, -- shows a list of your marks on ' and `
    registers = true, -- shows your registers on " in NORMAL or <C-r> in INSERT mode
    spelling = {
      enabled = true, -- enabling this will show WhichKey when pressing z= to select spelling suggestions
      suggestions = 20, -- how many suggestions should be shown in the list?
    },
    -- the presets plugin, adds help for a bunch of default keybindings in Neovim
    -- No actual key bindings are created
    presets = {
      operators = false, -- adds help for operators like d, y, ... and registers them for motion / text object completion
      motions = true, -- adds help for motions
      text_objects = true, -- help for text objects triggered after entering an operator
      windows = true, -- default bindings on <c-w>
      nav = true, -- misc bindings to work with windows
      z = true, -- bindings for folds, spelling and others prefixed with z
      g = true, -- bindings for prefixed with g
    },
  },
  -- add operators that will trigger motion and text object completion
  -- to enable all native operators, set the preset / operators plugin above
  -- operators = { gc = "Comments" },
  key_labels = {
    -- override the label used to display some keys. It doesn't effect WK in any other way.
    -- For example:
    -- ["<space>"] = "SPC",
    -- ["<cr>"] = "RET",
    -- ["<tab>"] = "TAB",
  },
  icons = {
    breadcrumb = "»", -- symbol used in the command line area that shows your active key combo
    separator = "➜", -- symbol used between a key and it's label
    group = "+", -- symbol prepended to a group
  },
  popup_mappings = {
    scroll_down = "<c-d>", -- binding to scroll down inside the popup
    scroll_up = "<c-u>", -- binding to scroll up inside the popup
  },
  window = {
    border = "rounded", -- none, single, double, shadow
    position = "bottom", -- bottom, top
    margin = { 1, 0, 1, 0 }, -- extra window margin [top, right, bottom, left]
    padding = { 2, 2, 2, 2 }, -- extra window padding [top, right, bottom, left]
    winblend = 0,
  },
  layout = {
    height = { min = 4, max = 25 }, -- min and max height of the columns
    width = { min = 20, max = 50 }, -- min and max width of the columns
    spacing = 3, -- spacing between columns
    align = "left", -- align columns left, center or right
  },
  ignore_missing = true, -- enable this to hide mappings for which you didn't specify a label
  hidden = { "<silent>", "<cmd>", "<Cmd>", "<CR>", "call", "lua", "^:", "^ " }, -- hide mapping boilerplate
  show_help = true, -- show help message on the command line when the popup is visible
  triggers = "auto", -- automatically setup triggers
  -- triggers = {"<leader>"} -- or specify a list manually
  triggers_blacklist = {
    -- list of mode / prefixes that should never be hooked by WhichKey
    -- this is mostly relevant for key maps that start with a native binding
    -- most people should not need to change this
    i = { "j", "k" },
    v = { "j", "k" },
  },
}

local opts = {
  mode = "n", -- NORMAL mode
  prefix = "<leader>",
  buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
  silent = true, -- use `silent` when creating keymaps
  noremap = true, -- use `noremap` when creating keymaps
  nowait = true, -- use `nowait` when creating keymaps
}

local vopts = {
  mode = "v", -- VISUAL mode
  prefix = "<leader>",
  buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
  silent = true, -- use `silent` when creating keymaps
  noremap = true, -- use `noremap` when creating keymaps
  nowait = true, -- use `nowait` when creating keymaps
}

 -- NOTE: Prefer using : over <cmd> as the latter avoids going back in normal-mode.
    -- see https://neovim.io/doc/user/map.html#:map-cmd
local vmappings = {
  ["/"] = { "<ESC><CMD>lua require('Comment.api').toggle_linewise_op(vim.fn.visualmode())<CR>", "Comment" },
} 

local mappings = {
  ["a"] = { "<cmd>Alpha<cr>", "Alpha" },
  ["w"] = { "<cmd>w!<CR>", "Save" },
  ["q"] = { "<cmd>q!<CR>", "Quit" },
  ["/"] = { "<cmd>lua require('Comment.api').toggle_current_linewise()<CR>", "Comment" },
  ["e"] = { "<cmd>NvimTreeToggle<cr>", "Explorer" },
  ["c"] = { "<cmd>Bdelete!<CR>", "Close Buffer" },
  ["h"] = { "<cmd>nohlsearch<CR>", "No Highlight" },
  ["f"] = { "<cmd>Telescope find_files<cr>", "Find files"},
  ["F"] = { "<cmd>Telescope live_grep theme=ivy<cr>", "Find Text" },
  ["P"] = { "<cmd>lua require('telescope').extensions.projects.projects()<cr>", "Projects" },

  ["b"] = { 
    name = "Buffer",
    b = { [[<cmd>lua require('telescope.builtin').buffers(require('telescope.themes').get_dropdown{previewer = false})<cr>]], "Browse Buffers" },
    c = { ":BufferClose<CR>", "Close Buffer" }, -- Close buffer
    p = { ":BufferPick<CR>", "Pick Buffer" }, -- Magic buffer-picking mode
    n = { ":BufferOrderByBufferNumber<CR>", "Buffer Order By Number" }, -- Sort automatically by buffer number
    d = { ":BufferOrderByDirectory<CR>", "Buffer Order By Directory" }, -- Sort automatically by directory
    l = { ":BufferOrderByLanguage<CR>", "Buffer Order By Language" }, -- Sort automatically by Language
  }, 

  B = {
    name = "Browser",
    b = { [[<Cmd>lua require('telescope').extensions.bookmarks.bookmarks()<CR>]], "Bookmarks page launch" },
  },

  p = {
    name = "Packer",
    c = { "<cmd>PackerCompile<cr>", "Compile" },
    i = { "<cmd>PackerInstall<cr>", "Install" },
    s = { "<cmd>PackerSync<cr>", "Sync" },
    S = { "<cmd>PackerStatus<cr>", "Status" },
    u = { "<cmd>PackerUpdate<cr>", "Update" },
  },

  g = {
    name = "Git",
    g = { "<cmd>lua _LAZYGIT_TOGGLE()<CR>", "Lazygit" },
    j = { "<cmd>lua require 'gitsigns'.next_hunk()<cr>", "Next Hunk" },
    k = { "<cmd>lua require 'gitsigns'.prev_hunk()<cr>", "Prev Hunk" },
    l = { "<cmd>lua require 'gitsigns'.blame_line()<cr>", "Blame" },
    P = { "<cmd>lua require 'gitsigns'.preview_hunk()<cr>", "Preview Hunk" },
    r = { "<cmd>lua require 'gitsigns'.reset_hunk()<cr>", "Reset Hunk" },
    R = { "<cmd>lua require 'gitsigns'.reset_buffer()<cr>", "Reset Buffer" },
    s = { "<cmd>lua require 'gitsigns'.stage_hunk()<cr>", "Stage Hunk" },
    u = { "<cmd>lua require 'gitsigns'.undo_stage_hunk()<cr>", "Undo Stage Hunk", },
    o = { "<cmd>Telescope git_status<cr>", "Open changed file" },
    --b = { "<cmd>Telescope git_branches<cr>", "Checkout branch" },
    --c = { "<cmd>Telescope git_commits<cr>", "Checkout commit" },
    d = { "<cmd>Gitsigns diffthis HEAD<cr>", "Diff", },
    n = { [[<Cmd>lua require'telescope-config'.project_files()<CR>]], "Git Files Project" }, -- find files with gitfiles & fallback on find_files
    b = { [[<Cmd>lua require'telescope.builtin'.git_branches({prompt_title = ' ', results_title='Git Branches'})<CR>]], "Git Branches" }, -- git telescope goodness -- git_branches
    C = { [[<Cmd>lua require'telescope.builtin'.git_bcommits({prompt_title = '  ', results_title='Git File Commits'})<CR>]], "Git File Commits" }, -- git_bcommits - file/buffer scoped commits to vsp diff
    c = { [[<Cmd>lua require'telescope.builtin'.git_commits()<CR>]], "Git Commits log" },-- git_commits (log) git log
    S = { [[<Cmd>lua require'telescope.builtin'.git_status()<CR>]], "Git Status Staging" },-- git_status - <tab> to toggle staging
    i = { [[<Cmd>lua require'telescope-config'.gh_issues()<CR>]], "Github issues" },-- Github issues
    p = { [[<Cmd>lua require'telescope-config'.gh_prs()<CR>]], "Github PRs" },-- github PRs
  },

  l = {
    name = "LSP",
    a = { "<cmd>lua vim.lsp.buf.code_action()<cr>", "Code Action" },
    f = { "<cmd>lua vim.lsp.buf.formatting()<cr>", "Format" },
    i = { "<cmd>LspInfo<cr>", "Info" },
    I = { "<cmd>LspInstallInfo<cr>", "Installer Info" },
    j = { "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", "Next Diagnostic", },
    k = { "<cmd>lua vim.lsp.diagnostic.goto_prev()<cr>", "Prev Diagnostic", },
    l = { "<cmd>lua vim.lsp.codelens.run()<cr>", "CodeLens Action" },
    q = { "<cmd>lua vim.lsp.diagnostic.set_loclist()<cr>", "Quickfix" },
    r = { "<cmd>lua vim.lsp.buf.rename()<cr>", "Rename" },
    d = { "<cmd>Telescope lsp_document_diagnostics<cr>", "Document Diagnostics", },
    w = { "<cmd>Telescope lsp_workspace_diagnostics<cr>", "Workspace Diagnostics", },
    s = { "<cmd>Telescope lsp_document_symbols<cr>", "Document Symbols" },
    S = { "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>", "Workspace Symbols", },
    t = { [[<Cmd>lua require'telescope.builtin'.lsp_implementations()<CR>]], "lsp implimentation" }, -- show LSP implementations
    n = { [[<Cmd>lua require'telescope.builtin'.lsp_definitions({layout_config = { preview_width = 0.50, width = 0.92 }, path_display = { "shorten" }, results_title='Definitions'})<CR>]], "lsp definitions" }, -- show LSP definitions
    n = { [[<Cmd>lua require'telescope.builtin'.lsp_workspace_diagnostics()<CR>]], "lsp workspace diagnostics" }, -- show LSP diagnostics for all open buffers
  },

  s = {
    name = "Telescope-Search",
    B = { "<cmd>Telescope git_branches<cr>", "Checkout branch" },
    C = { "<cmd>Telescope colorscheme<cr>", "Colorscheme" },
    r = { "<cmd>Telescope registers<cr>", "Registers" }, -- registers picker
    g = { "<cmd>Telescope gh run<cr>", "gh Run" }, 
    H = { [[<Cmd>lua require'telescope.builtin'.help_tags({results_title='Help Results'})<CR>]],"Help Results" },
    c = { [[<Cmd>lua require'telescope.builtin'.commands({results_title='Commands Results'})<CR>]],"Command Results" },
    k = { [[<Cmd>lua require'telescope.builtin'.keymaps({results_title='Key Maps Results'})<CR>]],"Key Maps Results" },
    e = { [[<Cmd>lua require'telescope.builtin'.find_files({find_command={'fd', vim.fn.expand('<cword>')}})<CR>]],"Find Files - Cusror Word" }, -- find files with names that contain cursor word
    F = { [[<Cmd>lua require'telescope-config'.file_explorer()<CR>]],"File Explorer - $Home" }, -- Explore files starting at $HOME
    f = { [[<Cmd>lua require'telescope'.extensions.file_browser.file_browser()<CR>]],"File Explorer - PWD" }, -- Browse files from cwd - File Browser
    o = { [[<Cmd>lua require'telescope.builtin'.oldfiles({results_title='Recent-ish Files'})<CR>]],"Open Recent Files" }, -- Telescope oldfiles
    b = { [[<Cmd>lua require'telescope.builtin'.buffers({prompt_title = '', results_title='﬘', winblend = 3, layout_strategy = 'vertical', layout_config = { width = 0.40, height = 0.55 }})<CR>]],"Explore Buffers" },
    m = { [[<Cmd>lua require'telescope.builtin'.marks({results_title='Marks Results'})<CR>]], "Marks Results" },
    M = { "<cmd>Telescope man_pages<cr>", "Man Pages" },
    n = { [[<Cmd>lua require'telescope-config'.browse_notes()<CR>]], "Notes-Browse" }, -- browse, explore and create notes
    N = { [[<Cmd>lua require'telescope-config'.find_notes()<CR>]], "Notes-Find" }, -- find notes
    t = { [[<Cmd>lua require'telescope-config'.find_configs()<CR>]], "Telescope Config" }, -- Find files in config dirs
    d = { [[<Cmd>lua require'telescope-config'.search_todos()<CR>]], "Nvim ToDo" }, -- Search through your Neovim related todos
    v = { [[<Cmd>lua require'telescope-config'.nvim_config()<CR>]], "Nvim Config" }, -- find or create neovim configs
    h = { [[<Cmd>lua require('telescope').extensions.notify.notify({results_title='Notification History', prompt_title='Search Messages'})<CR>]], "Notify History" }, -- telescope notify history
  },  

  G = {
    name = "Grep",
    l = { [[<Cmd>lua require('telescope.builtin').live_grep({grep_open_files=true})<CR>]], "grep open file" }, -- live grep 
    g = { [[<Cmd>lua require'telescope.builtin'.live_grep()<CR>]], "live grep" },
    n = { [[<Cmd>lua require'telescope-config'.grep_nvim_src()<CR>]], "grep Nvim" }, -- grep the Neovim source code with word under cursor → cword - just z to Neovim source for other actions
    w = { [[<Cmd>lua require'telescope.builtin'.grep_string()<CR>]], "grep cursor word" }, -- grep word under cursor
    W = { [[<Cmd>lua require'telescope.builtin'.grep_string({word_match='-w'})<CR>]], "grep cursor word -cs" }, -- grep word under cursor - case-sensitive (exact word) - made for use with Replace All - see <leader>ra
    p = { [[<Cmd>lua require'telescope-config'.grep_prompt()<CR>]], "grep prompt" }, -- grep for a string on prompt
    n = { [[<Cmd>lua require'telescope-config'.grep_notes()<CR>]], "grep notes" }, -- grep for a string in notes
  },

  t = {
    name = "Terminal",
    --n = { "<cmd>lua _NODE_TOGGLE()<cr>", "Node" },
    u = { "<cmd>lua _NCDU_TOGGLE()<cr>", "NCDU" },
    t = { "<cmd>lua _HTOP_TOGGLE()<cr>", "Htop" },
    p = { "<cmd>lua _PYTHON_TOGGLE()<cr>", "Python" },
    f = { "<cmd>ToggleTerm direction=float<cr>", "Float" },
    h = { "<cmd>ToggleTerm size=10 direction=horizontal<cr>", "Horizontal" },
    v = { "<cmd>ToggleTerm size=80 direction=vertical<cr>", "Vertical" },
  },
}

which_key.setup(setup)
which_key.register(mappings, opts)
which_key.register(vmappings, vopts)
