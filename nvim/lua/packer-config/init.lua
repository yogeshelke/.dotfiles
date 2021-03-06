return require("packer").startup(function()
	use("wbthomason/packer.nvim") --> packer plugin manager

	-->
	use("kyazdani42/nvim-web-devicons") --> enable icons
    use("nvim-lua/plenary.nvim")
	use("norcalli/nvim-colorizer.lua")
	use("nvim-lualine/lualine.nvim") --> a statusline written in lua
	use("romgrk/barbar.nvim") --> tabs for neovim
	use("kyazdani42/nvim-tree.lua") --> file explorer
	use("lukas-reineke/indent-blankline.nvim") --> indent guides for neovim
	use("akinsho/toggleterm.nvim")
	use("nvim-telescope/telescope.nvim") --> Find, Filter, Preview, Pick. All lua, all the time.
    use("BurntSushi/ripgrep")
	use("numToStr/Comment.nvim") -- Easily comment stuff
	use("ggandor/lightspeed.nvim") --> motion plugin with incremental input processing, allowing for unparalleled speed with near-zero cognitive effort
	use("rcarriga/nvim-notify")
	use("windwp/nvim-autopairs") -- Autopairs, integrates with both cmp and treesitter
	use("sunjon/shade.nvim") --> dim inactive windows
	use("Pocco81/TrueZen.nvim")
	use("fladson/vim-kitty") --> kitty syntax highlighting
	use("jubnzv/mdeval.nvim") --> evaluates code blocks inside markdown, vimwiki, orgmode.nvim and norg docs
	use("jbyuki/nabla.nvim")
	use("lewis6991/impatient.nvim") --> Casche based loading for faster NVIM performance
	use "antoinemadec/FixCursorHold.nvim" -- This is needed to fix lsp doc highlight
	use {"glepnir/dashboard-nvim",
	cmd = {
		"Dashboard",
		"DashboardChangeColorscheme",
		"DashboardFindFile",
		"DashboardFindHistory",
		"DashboardFindWord",
		"DashboardNewFile",
		"DashboardJumpMarks",
		"SessionLoad",
		"SessionSave"
	  },
	}
			-- config = function()
			--   require("~/.config/nvim/lua/dashboard-config/init.lua").config()
			-- end,
			-- disable = not config.enabled.dashboard,
	  
	--> colorschemes
	use("EdenEast/nightfox.nvim") --> nightfox colorsceme for neovim
	use("sainnhe/gruvbox-material")

	use("nvim-neorg/neorg")

	--> treesitter & treesitter modules/plugins
	use({ "nvim-treesitter/nvim-treesitter", run = ":TSUpdate" }) --> treesitter
    use("nvim-treesitter/nvim-treesitter-textobjects") --> textobjects
	use("nvim-treesitter/nvim-treesitter-refactor")
	use("p00f/nvim-ts-rainbow")
	use("nvim-treesitter/playground")
	use("JoosepAlviste/nvim-ts-context-commentstring")

	-- --> lsp
	-- use("neovim/nvim-lspconfig") --> Collection of configurations for built-in LSP client
	-- use("williamboman/nvim-lsp-installer") --> Companion plugin for lsp-config, allows us to seamlesly install language servers
	-- use("jose-elias-alvarez/null-ls.nvim") --> inject lsp diagnistocs, formattings, code actions, and more ...
	-- use("tami5/lspsaga.nvim") --> icons for LSP diagnostics
	-- use("onsails/lspkind-nvim") --> vscode-like pictograms for neovim lsp completion items
	-- use("hrsh7th/nvim-cmp") --> Autocompletion plugin
	-- use("hrsh7th/cmp-nvim-lsp") --> LSP source for nvim-cmp
	-- use("saadparwaiz1/cmp_luasnip") --> Snippets source for nvim-cmp
	-- use("L3MON4D3/LuaSnip") --> Snippets plugin
    -- use("preservim/vimux") --> Vimux: easily interact with tmux from vim

-->--------------------------------------------------------------------
  -- cmp plugins
  use "hrsh7th/nvim-cmp" -- The completion plugin
  use "hrsh7th/cmp-buffer" -- buffer completions
  use "hrsh7th/cmp-path" -- path completions
  use "hrsh7th/cmp-cmdline" -- cmdline completions
  use "saadparwaiz1/cmp_luasnip" -- snippet completions
  use "hrsh7th/cmp-nvim-lsp"

  -- snippets
  use "L3MON4D3/LuaSnip" --snippet engine
  use "rafamadriz/friendly-snippets" -- a bunch of snippets to use

  -- LSP
  use "neovim/nvim-lspconfig" -- enable LSP
  use "williamboman/nvim-lsp-installer" -- simple to use language server installer
  use "tamago324/nlsp-settings.nvim" -- language server settings defined in json for
  use "jose-elias-alvarez/null-ls.nvim" -- for formatters and linters
  use ("tami5/lspsaga.nvim") --> icons for LSP diagnostics
  use("onsails/lspkind-nvim") --> vscode-like pictograms for neovim lsp completion items
  -->--------------------------------------------------------------------



    --> telescope modules and plugins
	use({'tami5/sqlite.lua', module = 'sqlite'})
	use("nvim-lua/popup.nvim")
    
	use("dhruvmanila/telescope-bookmarks.nvim")
    use("nvim-telescope/telescope-file-browser.nvim")
	use{'nvim-telescope/telescope-fzf-native.nvim', run = 'make' }
	use("jvgrootveld/telescope-zoxide")
	use("cljoly/telescope-repo.nvim")
	use("AckslD/nvim-neoclip.lua")
	use("nvim-telescope/telescope-github.nvim")
	use("nvim-telescope/telescope-media-files.nvim")
	use("nvim-telescope/telescope-project.nvim")
	
	--> GIT Plugins
	use("lewis6991/gitsigns.nvim") -- git decorations implemented purely in lua/teal
	use("tpope/vim-fugitive")
	use("tpope/vim-rhubarb")
	use("junegunn/gv.vim")

	--> Diaplays key bindings
	use "folke/which-key.nvim"

end)


