#!/usr/bin/env bash

###############################################################################
# Bootstrap Script for macOS Dotfiles Setup
# This script sets up a new Mac with all configurations and applications
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get the directory where this script is located
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

info "Starting dotfiles setup..."
info "Dotfiles directory: $DOTFILES_DIR"

###############################################################################
# Install Homebrew
###############################################################################
if ! command -v brew &> /dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == 'arm64' ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    success "Homebrew installed successfully"
else
    success "Homebrew already installed"
fi

###############################################################################
# Install packages from Brewfile
###############################################################################
if [ -f "$DOTFILES_DIR/Brewfile" ]; then
    info "Installing packages from Brewfile..."
    brew bundle --file="$DOTFILES_DIR/Brewfile" || warning "Some packages failed to install"
    success "Brewfile packages installed"
else
    warning "Brewfile not found, skipping package installation"
fi

###############################################################################
# Setup Zsh configuration
###############################################################################
info "Setting up Zsh configuration..."

# Install Oh My Zsh if not present
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    success "Oh My Zsh installed"
else
    success "Oh My Zsh already installed"
fi

# Backup existing .zshrc if it exists and is not a symlink
if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
    warning "Backing up existing .zshrc to .zshrc.backup"
    mv "$HOME/.zshrc" "$HOME/.zshrc.backup"
fi

# Create symlink for .zshrc
if [ -f "$DOTFILES_DIR/zsh/.zshrc" ]; then
    ln -sf "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
    success "Linked .zshrc"
fi

# Create symlink for Powerlevel10k configuration
if [ -f "$DOTFILES_DIR/powerlevel10k/.p10k.zsh" ]; then
    ln -sf "$DOTFILES_DIR/powerlevel10k/.p10k.zsh" "$HOME/.p10k.zsh"
    success "Linked .p10k.zsh"
fi

###############################################################################
# Setup Git configuration
###############################################################################
info "Setting up Git configuration..."

# Backup existing .gitconfig if it exists and is not a symlink
if [ -f "$HOME/.gitconfig" ] && [ ! -L "$HOME/.gitconfig" ]; then
    warning "Backing up existing .gitconfig to .gitconfig.backup"
    mv "$HOME/.gitconfig" "$HOME/.gitconfig.backup"
fi

# Create symlink for .gitconfig
if [ -f "$DOTFILES_DIR/git/.gitconfig" ]; then
    ln -sf "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
    success "Linked .gitconfig"
fi

###############################################################################
# Setup Neovim configuration
###############################################################################
info "Setting up Neovim configuration..."

# Create .config directory if it doesn't exist
mkdir -p "$HOME/.config"

# Backup existing nvim config if it exists and is not a symlink
if [ -d "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
    warning "Backing up existing nvim config to nvim.backup"
    mv "$HOME/.config/nvim" "$HOME/.config/nvim.backup"
fi

# Create symlink for nvim configuration
if [ -d "$DOTFILES_DIR/nvim" ]; then
    ln -sf "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"
    success "Linked Neovim configuration"
fi

###############################################################################
# Setup VSCode/Cursor configuration
###############################################################################
info "Setting up VSCode/Cursor configuration..."

VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
mkdir -p "$VSCODE_USER_DIR"

# Backup and link settings.json
if [ -f "$VSCODE_USER_DIR/settings.json" ] && [ ! -L "$VSCODE_USER_DIR/settings.json" ]; then
    warning "Backing up existing settings.json"
    mv "$VSCODE_USER_DIR/settings.json" "$VSCODE_USER_DIR/settings.json.backup"
fi

if [ -f "$DOTFILES_DIR/vscode/settings.json" ]; then
    ln -sf "$DOTFILES_DIR/vscode/settings.json" "$VSCODE_USER_DIR/settings.json"
    success "Linked VSCode settings.json"
fi

# Backup and link keybindings.json if it exists
if [ -f "$DOTFILES_DIR/vscode/keybindings.json" ]; then
    if [ -f "$VSCODE_USER_DIR/keybindings.json" ] && [ ! -L "$VSCODE_USER_DIR/keybindings.json" ]; then
        warning "Backing up existing keybindings.json"
        mv "$VSCODE_USER_DIR/keybindings.json" "$VSCODE_USER_DIR/keybindings.json.backup"
    fi
    ln -sf "$DOTFILES_DIR/vscode/keybindings.json" "$VSCODE_USER_DIR/keybindings.json"
    success "Linked VSCode keybindings.json"
fi

###############################################################################
# Setup iTerm2 configuration
###############################################################################
if [ -f "$DOTFILES_DIR/iterm2/com.googlecode.iterm2.plist" ]; then
    info "Setting up iTerm2 configuration..."
    
    # Copy iTerm2 preferences
    cp "$DOTFILES_DIR/iterm2/com.googlecode.iterm2.plist" "$HOME/Library/Preferences/com.googlecode.iterm2.plist"
    
    # Tell iTerm2 to load preferences from custom folder (optional)
    # defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$DOTFILES_DIR/iterm2"
    # defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
    
    success "iTerm2 configuration set up"
    warning "You may need to restart iTerm2 for changes to take effect"
fi

###############################################################################
# Setup Zellij configuration
###############################################################################
info "Setting up Zellij configuration..."

# Create Zellij config directories
mkdir -p "$HOME/.config/zellij"
mkdir -p "$HOME/.config/zellij_layout"

# Backup and link main config if it exists
if [ -f "$DOTFILES_DIR/zellij/config.kdl" ]; then
    if [ -f "$HOME/.config/zellij/config.kdl" ] && [ ! -L "$HOME/.config/zellij/config.kdl" ]; then
        warning "Backing up existing Zellij config"
        mv "$HOME/.config/zellij/config.kdl" "$HOME/.config/zellij/config.kdl.backup"
    fi
    ln -sf "$DOTFILES_DIR/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
    success "Linked Zellij config"
fi

# Link Zellij layouts
if [ -d "$DOTFILES_DIR/zellij/layouts" ]; then
    for layout in "$DOTFILES_DIR/zellij/layouts"/*.kdl; do
        if [ -f "$layout" ]; then
            layout_name=$(basename "$layout")
            if [ -f "$HOME/.config/zellij_layout/$layout_name" ] && [ ! -L "$HOME/.config/zellij_layout/$layout_name" ]; then
                warning "Backing up existing Zellij layout: $layout_name"
                mv "$HOME/.config/zellij_layout/$layout_name" "$HOME/.config/zellij_layout/$layout_name.backup"
            fi
            ln -sf "$layout" "$HOME/.config/zellij_layout/$layout_name"
            success "Linked Zellij layout: $layout_name"
        fi
    done
fi

###############################################################################
# macOS System Preferences (Optional)
###############################################################################
info "Would you like to apply recommended macOS system preferences? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    info "Applying macOS system preferences..."
    
    # Show hidden files in Finder
    defaults write com.apple.finder AppleShowAllFiles -bool true
    
    # Show path bar in Finder
    defaults write com.apple.finder ShowPathbar -bool true
    
    # Show status bar in Finder
    defaults write com.apple.finder ShowStatusBar -bool true
    
    # Disable the "Are you sure you want to open this application?" dialog
    defaults write com.apple.LaunchServices LSQuarantine -bool false
    
    # Expand save panel by default
    defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
    defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
    
    # Save to disk (not to iCloud) by default
    defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
    
    # Restart Finder to apply changes
    killall Finder
    
    success "macOS preferences applied"
fi

###############################################################################
# Final Steps
###############################################################################
echo ""
success "✨ Dotfiles setup complete! ✨"
echo ""
info "Next steps:"
echo "  1. Restart your terminal or run: source ~/.zshrc"
echo "  2. If using iTerm2, restart it to load new preferences"
echo "  3. Open Neovim and run :PackerSync to install plugins"
echo "  4. Review your Git configuration and update user email/name if needed"
echo ""
info "Your old configurations have been backed up with .backup extension"
echo ""
