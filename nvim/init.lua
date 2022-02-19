
require("packer-config")
require("options")
require("keymap-config")
require("keymap-config.vscdkeymap")
require("autopairs-config")
require("lualine-config")
require("barbar-config")
require("colors-config.nightfox")
require("nvim-tree-config")
require("toggleterm-config")
require("comment-nvim-config")
require("neorg-config")
require("colorizer-config")
require("indent-blankline-config")
require("shade-config")
require("telescope-config")
require("project-config")
require("truezen-config")
-- require("mdeval-config")
require("whichkey-config")
require("dashboard-config")
require("impatient-config")

--> tree-sitter and tree-sitter plugins
require("treesitter-config")

--> lsp modules
require("lsp-config.language-servers")
require("lsp-config.lspsaga")
require("lsp-config.completion")
require("lsp-config.null-ls")
require("cmp-config")

-- require("lspnew-config")
-- require("lspnew-config.handlers")
-- require("lspnew-config.lsp-installer")
-- require("lspnew-config.null-ls")
--require("lspnew-config.settings.jsonls")
--require("lspnew-config.settings.sumneko_lua")

-- git modules
require("gitsigns-config")
--vim.cmd('colorscheme nord')



