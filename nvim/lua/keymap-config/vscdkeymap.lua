
local map = function(mode, key, command)
	vim.api.nvim_set_keymap(mode, key, command, {
		noremap = true,
		silent = true
	})
end

function CopyCurrentLineToClipboard()
    local ft = vim.bo.filetype
    if ft == "NvimTree" then
        require"nvim-tree".on_keypress("copy_absolute_path")
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

    vim.api.nvim_set_keymap("n", key, command,
                            { noremap = noremap, silent = silent, expr = expr })
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

    vim.api.nvim_set_keymap("i", key, command,
                            { noremap = noremap, silent = silent, expr = expr })
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

    vim.api.nvim_set_keymap("v", key, command,
                            { noremap = noremap, silent = silent, expr = expr })

end

--> text selection with shift + left/right just like vs code
-- left
nnoremap{"<S-left>", "v<left>"}
inoremap{"<S-left>", "<esc>v<left>"}
vnoremap{"<S-left>", "<left>"}
-- right
nnoremap{"<S-right>", "v<right>"}
inoremap{"<S-right>", "<c-o><right><esc>v<right>"}
vnoremap{"<S-right>", "<right>"}




--> Selection Up and Down --
-- trigger visual line from insert mode
map ( "i", "<S-up>", "<c-o><S-v>k" )
map ( "i", "<S-down>", "<c-o><S-v>j" )
map ( "v", "<S-up>", "<up>" )
map ( "v", "<S-down>", "<down>" )
-- trigger visual line from normal mode using shift
map ( "n", "<S-up>", "<S-v>k" )
map ( "n", "<S-down>", "<S-v>j" )


--> copy paste like vs code
-- trigger visual line from insert mode
map ( "n", "<C-c>", ":lua CopyCurrentLineToClipboard()<CR>" )
map ( "i", "<C-c>", "<C-o>:lua CopyCurrentLineToClipboard()<CR>" )
-- trigger visual line from normal mode 
map ( "v", "<C-c>", "\"+ygv" )


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
