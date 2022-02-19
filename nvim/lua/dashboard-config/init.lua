
  local g = vim.g
  local fn = vim.fn
  local plugins_count = fn.len(fn.globpath("~/.local/share/nvim/site/pack/packer/start", "*", 0, 1))

  g.dashboard_disable_statusline = 1
  g.dashboard_default_executive = "telescope"
  g.dashboard_custom_header = {
    "MMMMMNNNNXMMMMNNNNNXMMMMMNNNNNXMMMMMNNNNNXMMMMMNNNNNXMMMMMNNNNNXMMMMMNNNNNXMMMMMNNNNNMMMNNNKXXXX",
    "MMMM                                                  .lk0K0x,                              XXXX",
    "MMMN                                                ,KXXXXXXXO:'.                           XXXX",
    "MMMN                                       .l'      kXXXXXXXXXXK.     .k.                   XXXX",
    "MMMN                                        .xOc.   ,KXXXXXXXX0'     :KX.                   XXXX",
    "MMMN                           .;cloolc;.     :KX0o,..:dOK0ko,    .c0XXX,                   XXXX",
    "MMMN                       .ckKXXXXXXXXXXXkc.  .dXXXXOdl:;,,,;:ld0XXXXXXd                   XXXX",
    "MMMN                     ;kXXXXXXXXXXXXXXXXXXx'  .lKXXXXXXXXXXXXXXXXXXXK:                   XXXX",
    "MMMN                   :0XXXXXXXXXXXXXXXXXXXXXXx.   ,o0XXXXXXXXXXXXXKx:                     XXXX",
    "MMMN                .l0XXXXXXXXXXXXXXXXXXXXXXXXX0.     .';clodddoc;.                        XXXX",
    "MMMN             .lKXXXXXXXXXXXXXKkolcld0XXXXXXXXc           .,cdxkOkxdl;.                  XXXX",
    "MMMN               .o0XXXXXXXXkl'        ,0XXXXXXl         :kXXXXXXXXXXXXX0l.               XXXX",
    "MMMN                  .;cll:'             .KXXXXX'       cKXXXXXXXXXXXXXXXXXKl              XXXX",
    "MMMN                                      .KXXXX:      .OXXXXXXXXXX0o,..'ckXXXk.            XXXX",
    "MMMN                                     ,0XXXK,      .KXXXXXXXXXXl        'OXXk            XXXX",
    "MMMN                     ...        .':d0XXXXx.      .0XXXXXXXXX0'           kXXl           XXXX",
    "MMMN                     .0XXXKKKKXXXXXXXXXk,       'KXXXXXXXXXx.            .KXK.          XXXX",
    "MMMN                      .OXXXXXXXXXXXXXK:        oXXXXXXXXXXl               OXX:          XXXX",
    "MMMN          ,.           .dXXXXXXXXXXXXXXkl;',;oKXXXXXXXXXk.                OXXd          XXXX",
    "MMMN          co             .o0XXXXXXXXXXXXXXXXXXXXXXXXXXO;                 'XXXk          XXXX",
    "MMMN          oX'               .';:cc:clxKXXXXXX0ccccc:,.                   kXXXO          XXXX",
    "MMMN          dXO.                         ;0XXXXXc     .                   dXXXXk          XXXX",
    "MMMN          lXXx                          .KXXXXX'   .0.                .xXXXXXo          XXXX",
    "MMMN          ;XXXd                          xXXXXXO   ;X0,              c0XXXXXX,          XXXX",
    "MMMN          .XXXXx                         dXXXXXX,  ;XXXk;.       .,oKXXXXXXXO           XXXX",
    "MMMN           xXXXX0,                      .KXXXXXXo  .KXXXXX0kddxk0XXXXXXXXXXK'           XXXX",
    "MMMN           .KXXXXXk,                   ,0XXXXXXXd   oXXXXXXXXXXXXXXXXXXXXKc             XXXX",
    "MMMN            :XXXXXXXKo;.           .'lOXXXXXXXXl     xXXXXXXXXXXXXXXXXXXK;              XXXX",
    "MMMN             :KXXXXXXXXXKkdlccclox0XXXXXXXXXXXK.      lKXXXXXXXXXXXXXKd.                XXXX",
    "MMMN                ;kXXXXXXXXXXXXXXXXXXXXXXXXXXXk.           .,:llll:,.                    XXXX",
    "MMMX                  .l0XXXXXXXXXXXXXXXXXXXXKo'                                            XXXX",
    "MMMX                     .:x0XXXXXXXXXXXX0xl'                                               XXXX",
    "MMMN                         ..;:llll:.                                                     XXXX",
    "MMMNNNNXMMNNNNNXMMMMMNNNNNXMMMMMNNNNNXMMMMMNNNNNXMMMMMNNNNNXMMMMMNNNNNXMMMMMNNNXMMMMMNNNNNXMXXXX",
   }
  g.dashboard_custom_section = {
    a = { description = { "  Find File                                            SPC f f" }, command = "Telescope find_files" },
    b = { description = { "  Find directory                                       SPC f d" }, command = "Telescope find_directories" },
    c = { description = { "  Recents                                              SPC f o" }, command = "Telescope oldfiles" },
    d = { description = { "  Find Word                                            SPC f w" }, command = "Telescope live_grep" },
    e = { description = { "  New File                                             SPC f n" }, command = "DashboardNewFile" },
    f = { description = { "  Bookmarks                                            SPC B b" }, command = "Telescope marks" },
    g = { description = { "  Load Last Session                                    SPC s l" }, command = "SessionLoad" },
   	i = { description = { "  Quit Neovim                                          SPC q   "}, command = ":q<CR>"},
  }
 g.dashboard_custom_footer = {    
    " Girizaś OmVim loaded " .. plugins_count .. " plugins ",
  }
