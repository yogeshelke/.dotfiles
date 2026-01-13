# 🚀 Dotfiles

My personal macOS dotfiles for quick system setup and configuration management.

## 📦 What's Included

- **Brewfile**: All Homebrew packages, casks, and Mac App Store apps
- **Zsh Configuration**: `.zshrc` with aliases, functions, and shell settings
- **Git Configuration**: `.gitconfig` with useful aliases and settings
- **Neovim**: Complete Neovim configuration with plugins
- **Powerlevel10k**: Terminal theme configuration
- **VSCode/Cursor**: Editor settings and keybindings
- **iTerm2**: Terminal emulator preferences
- **Zellij**: Terminal multiplexer configuration and layouts
- **Bootstrap Script**: Automated setup for new machines

## 🎯 Quick Start

### Fresh macOS Setup

1. **Clone this repository:**
   ```bash
   git clone https://github.com/yourusername/dotfiles.git ~/.dotfiles
   cd ~/.dotfiles
   ```

2. **Run the bootstrap script:**
   ```bash
   ./bootstrap.sh
   ```

3. **Restart your terminal** and enjoy your configured environment!

### Manual Setup (Alternative)

If you prefer manual setup or want to cherry-pick configurations:

```bash
# Install Homebrew packages
brew bundle --file=~/.dotfiles/Brewfile

# Link configurations
ln -sf ~/.dotfiles/zsh/.zshrc ~/.zshrc
ln -sf ~/.dotfiles/git/.gitconfig ~/.gitconfig
ln -sf ~/.dotfiles/nvim ~/.config/nvim
ln -sf ~/.dotfiles/powerlevel10k/.p10k.zsh ~/.p10k.zsh
ln -sf ~/.dotfiles/vscode/settings.json ~/Library/Application\ Support/Code/User/settings.json

# Setup Zellij
mkdir -p ~/.config/zellij ~/.config/zellij_layout
ln -sf ~/.dotfiles/zellij/config.kdl ~/.config/zellij/config.kdl
ln -sf ~/.dotfiles/zellij/layouts/*.kdl ~/.config/zellij_layout/

# Copy iTerm2 preferences
cp ~/.dotfiles/iterm2/com.googlecode.iterm2.plist ~/Library/Preferences/
```

## 📁 Repository Structure

```
.dotfiles/
├── bootstrap.sh                 # Automated setup script
├── Brewfile                     # Homebrew packages
├── git/
│   └── .gitconfig              # Git configuration
├── zsh/
│   └── .zshrc                  # Zsh configuration
├── powerlevel10k/
│   └── .p10k.zsh               # Powerlevel10k theme config
├── nvim/                        # Neovim configuration
│   ├── init.lua
│   └── lua/                    # Plugin configurations
├── vscode/
│   ├── settings.json           # VSCode/Cursor settings
│   └── keybindings.json        # Custom keybindings (if any)
├── zellij/
│   ├── config.kdl              # Zellij main config
│   └── layouts/                # Zellij layout files
│       └── terraform_proj.kdl  # Terraform project layout
└── iterm2/
    └── com.googlecode.iterm2.plist  # iTerm2 preferences
```

## 🔄 Keeping Your Dotfiles Updated

### Backup Current Configurations

After making changes to your local configurations, update the dotfiles repo:

```bash
# Update Brewfile
cd ~/.dotfiles
brew bundle dump --force --file=./Brewfile

# Copy updated configs
cp ~/.zshrc ./zsh/.zshrc
cp ~/.gitconfig ./git/.gitconfig
cp ~/.p10k.zsh ./powerlevel10k/.p10k.zsh
cp ~/Library/Application\ Support/Code/User/settings.json ./vscode/settings.json
cp ~/Library/Preferences/com.googlecode.iterm2.plist ./iterm2/
cp ~/.config/zellij/config.kdl ./zellij/config.kdl
cp ~/.config/zellij_layout/*.kdl ./zellij/layouts/

# Commit and push
git add .
git commit -m "Update dotfiles"
git push
```

### Pull Latest Changes

On any machine with your dotfiles:

```bash
cd ~/.dotfiles
git pull
./bootstrap.sh  # Re-run to update symlinks if needed
```

## ⚙️ What the Bootstrap Script Does

1. ✅ Installs Homebrew (if not present)
2. ✅ Installs all packages from Brewfile
3. ✅ Sets up Oh My Zsh
4. ✅ Creates symlinks for all configuration files
5. ✅ Backs up existing configs (with `.backup` extension)
6. ✅ Configures Neovim
7. ✅ Sets up VSCode/Cursor settings
8. ✅ Installs iTerm2 preferences
9. ✅ Optionally applies macOS system preferences

## 🔒 Security Notes

- SSH private keys and sensitive credentials are **NOT** included
- The `.gitignore` is configured to prevent accidental commits of sensitive data
- Review and update personal information in `.gitconfig` (email, name, signing key)
- AWS credentials, Kubernetes configs, and other secrets are excluded

## 📝 Customization

### Adding New Packages

```bash
# Install a package
brew install package-name

# Update Brewfile
brew bundle dump --force --file=~/.dotfiles/Brewfile
```

### Modifying Configurations

1. Edit the files in `~/.dotfiles/` (they're symlinked to your home directory)
2. Test your changes
3. Commit and push to keep them synced

## 🛠️ Troubleshooting

### Homebrew Installation Fails
- Ensure you have Xcode Command Line Tools: `xcode-select --install`
- Check Homebrew requirements: https://docs.brew.sh/Installation

### Symlink Conflicts
- The bootstrap script backs up existing files with `.backup` extension
- Manually remove conflicting files if needed

### Neovim Plugin Issues
- Open Neovim and run `:PackerSync` to install/update plugins
- Run `:checkhealth` to diagnose issues

### iTerm2 Preferences Not Loading
- Restart iTerm2 after running bootstrap
- Or manually load: iTerm2 → Preferences → General → Preferences → Load preferences from custom folder

## 📚 Resources

- [Homebrew Documentation](https://docs.brew.sh/)
- [Oh My Zsh](https://ohmyz.sh/)
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- [Neovim](https://neovim.io/)
- [Packer.nvim](https://github.com/wbthomason/packer.nvim)

## 📄 License

Feel free to use and modify these dotfiles for your own setup!

---

**Happy Hacking! 🎉**
