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

# Create a symlink, handling existing files/symlinks properly
# Usage: create_symlink <source> <target>
create_symlink() {
    local source="$1"
    local target="$2"
    local target_name=$(basename "$target")
    
    # Check if source exists
    if [ ! -e "$source" ]; then
        warning "Source does not exist: $source"
        return 1
    fi
    
    # If target is a symlink (valid or broken), remove it
    if [ -L "$target" ]; then
        local current_target=$(readlink "$target" 2>/dev/null || echo "")
        if [ "$current_target" = "$source" ]; then
            success "Symlink already correct: $target_name"
            return 0
        else
            info "Updating symlink: $target_name (was pointing to: $current_target)"
            rm "$target"
        fi
    # If target is a regular file/directory, back it up
    elif [ -e "$target" ]; then
        warning "Backing up existing $target_name to ${target_name}.backup"
        mv "$target" "${target}.backup"
    fi
    
    # Create the symlink
    ln -sf "$source" "$target"
    
    # Verify the symlink was created correctly
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        success "Linked $target_name -> $source"
        return 0
    else
        error "Failed to create symlink: $target_name"
        return 1
    fi
}

# Verify a symlink points to the correct location
verify_symlink() {
    local target="$1"
    local expected_source="$2"
    
    if [ -L "$target" ]; then
        local actual_source=$(readlink "$target")
        if [ "$actual_source" = "$expected_source" ]; then
            return 0
        fi
    fi
    return 1
}

# Get the directory where this script is located
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Handle command line arguments
VERIFY_ONLY=false
FIX_SYMLINKS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --verify|-v)
            VERIFY_ONLY=true
            shift
            ;;
        --fix-symlinks|-f)
            FIX_SYMLINKS=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --verify, -v       Only verify symlinks without making changes"
            echo "  --fix-symlinks, -f Only fix symlinks without full bootstrap"
            echo "  --help, -h         Show this help message"
            echo ""
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

info "Starting dotfiles setup..."
info "Dotfiles directory: $DOTFILES_DIR"

# If --verify flag is set, skip to verification
if $VERIFY_ONLY; then
    info "Running in verify-only mode..."
fi

###############################################################################
# Detect Architecture
###############################################################################
ARCH=$(uname -m)
if [[ "$ARCH" == 'arm64' ]]; then
    HOMEBREW_PREFIX="/opt/homebrew"
    info "Detected: Apple Silicon (arm64)"
else
    HOMEBREW_PREFIX="/usr/local"
    info "Detected: Intel (x86_64)"
fi

###############################################################################
# Install Homebrew
###############################################################################
if ! $VERIFY_ONLY && ! $FIX_SYMLINKS; then
if ! command -v brew &> /dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH
    echo "eval \"\$(${HOMEBREW_PREFIX}/bin/brew shellenv)\"" >> ~/.zprofile
    eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)"
    success "Homebrew installed successfully"
else
    success "Homebrew already installed"
fi
fi # end VERIFY_ONLY/FIX_SYMLINKS check

###############################################################################
# Install packages from Brewfile
###############################################################################
if ! $VERIFY_ONLY && ! $FIX_SYMLINKS; then
if [ -f "$DOTFILES_DIR/Brewfile" ]; then
    info "Installing packages from Brewfile..."
    brew bundle --file="$DOTFILES_DIR/Brewfile" || warning "Some packages failed to install"
    success "Brewfile packages installed"
else
    warning "Brewfile not found, skipping package installation"
fi
fi # end VERIFY_ONLY/FIX_SYMLINKS check

###############################################################################
# Setup Zsh configuration
###############################################################################
if ! $VERIFY_ONLY; then
info "Setting up Zsh configuration..."

# Install Oh My Zsh if not present (skip if only fixing symlinks)
if ! $FIX_SYMLINKS; then
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        success "Oh My Zsh installed"
    else
        success "Oh My Zsh already installed"
    fi

    # Install Powerlevel10k theme for Oh My Zsh
    P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    if [ ! -d "$P10K_DIR" ]; then
        info "Installing Powerlevel10k theme..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
        success "Powerlevel10k theme installed"
    else
        success "Powerlevel10k theme already installed"
    fi

    # Install zsh-autosuggestions plugin
    ZSH_AUTOSUGGESTIONS_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    if [ ! -d "$ZSH_AUTOSUGGESTIONS_DIR/.git" ]; then
        info "Installing zsh-autosuggestions plugin..."
        rm -rf "$ZSH_AUTOSUGGESTIONS_DIR"
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AUTOSUGGESTIONS_DIR"
        success "zsh-autosuggestions plugin installed"
    else
        success "zsh-autosuggestions plugin already installed"
    fi

    # Install zsh-syntax-highlighting plugin
    ZSH_SYNTAX_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    if [ ! -d "$ZSH_SYNTAX_DIR/.git" ]; then
        info "Installing zsh-syntax-highlighting plugin..."
        rm -rf "$ZSH_SYNTAX_DIR"
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_SYNTAX_DIR"
        success "zsh-syntax-highlighting plugin installed"
    else
        success "zsh-syntax-highlighting plugin already installed"
    fi
fi # end FIX_SYMLINKS check

# Create symlink for .zshrc
if [ -f "$DOTFILES_DIR/zsh/.zshrc" ]; then
    create_symlink "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
fi

# Create symlink for Powerlevel10k configuration
if [ -f "$DOTFILES_DIR/powerlevel10k/.p10k.zsh" ]; then
    create_symlink "$DOTFILES_DIR/powerlevel10k/.p10k.zsh" "$HOME/.p10k.zsh"
fi
fi # end VERIFY_ONLY check for Zsh configuration

###############################################################################
# Setup Git configuration
###############################################################################
if ! $VERIFY_ONLY; then
info "Setting up Git configuration..."

# Create symlink for .gitconfig
if [ -f "$DOTFILES_DIR/git/.gitconfig" ]; then
    create_symlink "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
fi
fi # end VERIFY_ONLY check for Git configuration

###############################################################################
# Setup Neovim configuration
###############################################################################
if ! $VERIFY_ONLY; then
info "Setting up Neovim configuration..."

# Create .config directory if it doesn't exist
mkdir -p "$HOME/.config"

# Create symlink for nvim configuration
if [ -d "$DOTFILES_DIR/nvim" ]; then
    create_symlink "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"
fi
fi # end VERIFY_ONLY check for Neovim configuration

###############################################################################
# Setup VSCode/Cursor configuration
###############################################################################
if ! $VERIFY_ONLY && ! $FIX_SYMLINKS; then
info "Setting up VSCode/Cursor configuration..."

VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
mkdir -p "$VSCODE_USER_DIR"

# Link settings.json
if [ -f "$DOTFILES_DIR/vscode/settings.json" ]; then
    create_symlink "$DOTFILES_DIR/vscode/settings.json" "$VSCODE_USER_DIR/settings.json"
fi

# Link keybindings.json if it exists
if [ -f "$DOTFILES_DIR/vscode/keybindings.json" ]; then
    create_symlink "$DOTFILES_DIR/vscode/keybindings.json" "$VSCODE_USER_DIR/keybindings.json"
fi
fi # end VERIFY_ONLY/FIX_SYMLINKS check for VSCode configuration

###############################################################################
# Setup iTerm2 configuration
###############################################################################
if ! $VERIFY_ONLY && ! $FIX_SYMLINKS; then
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
fi # end VERIFY_ONLY/FIX_SYMLINKS check for iTerm2 configuration

###############################################################################
# Setup k9s configuration
###############################################################################
if ! $VERIFY_ONLY; then
info "Setting up k9s configuration..."

# Create k9s config directories
mkdir -p "$HOME/.config/k9s/skins"

# Link k9s config
if [ -f "$DOTFILES_DIR/k9s/config.yaml" ]; then
    create_symlink "$DOTFILES_DIR/k9s/config.yaml" "$HOME/.config/k9s/config.yaml"
fi

# Link k9s skins
if [ -d "$DOTFILES_DIR/k9s/skins" ]; then
    for skin in "$DOTFILES_DIR/k9s/skins"/*.yaml; do
        if [ -f "$skin" ]; then
            skin_name=$(basename "$skin")
            create_symlink "$skin" "$HOME/.config/k9s/skins/$skin_name"
        fi
    done
fi
fi # end VERIFY_ONLY check for k9s configuration

###############################################################################
# Setup Zellij configuration
###############################################################################
if ! $VERIFY_ONLY; then
info "Setting up Zellij configuration..."

# Create Zellij config directories
mkdir -p "$HOME/.config/zellij"
mkdir -p "$HOME/.config/zellij_layout"

# Link main config if it exists
if [ -f "$DOTFILES_DIR/zellij/config.kdl" ]; then
    create_symlink "$DOTFILES_DIR/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
fi

# Link Zellij layouts
if [ -d "$DOTFILES_DIR/zellij/layouts" ]; then
    for layout in "$DOTFILES_DIR/zellij/layouts"/*.kdl; do
        if [ -f "$layout" ]; then
            layout_name=$(basename "$layout")
            create_symlink "$layout" "$HOME/.config/zellij_layout/$layout_name"
        fi
    done
fi
fi # end VERIFY_ONLY check for Zellij configuration

###############################################################################
# macOS System Preferences (Optional)
###############################################################################
if ! $VERIFY_ONLY && ! $FIX_SYMLINKS; then
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
fi # end VERIFY_ONLY/FIX_SYMLINKS check for macOS preferences

###############################################################################
# Verify Symlinks
###############################################################################
info "Verifying symlinks..."

verify_all_symlinks() {
    local all_ok=true
    
    echo ""
    echo "Symlink Status:"
    echo "==============="
    
    # Check each symlink
    local symlinks=(
        "$HOME/.zshrc:$DOTFILES_DIR/zsh/.zshrc"
        "$HOME/.p10k.zsh:$DOTFILES_DIR/powerlevel10k/.p10k.zsh"
        "$HOME/.gitconfig:$DOTFILES_DIR/git/.gitconfig"
        "$HOME/.config/nvim:$DOTFILES_DIR/nvim"
        "$HOME/.config/k9s/config.yaml:$DOTFILES_DIR/k9s/config.yaml"
        "$HOME/.config/k9s/skins/nord.yaml:$DOTFILES_DIR/k9s/skins/nord.yaml"
        "$HOME/.config/zellij/config.kdl:$DOTFILES_DIR/zellij/config.kdl"
        "$HOME/.config/zellij_layout/terraform_proj.kdl:$DOTFILES_DIR/zellij/layouts/terraform_proj.kdl"
    )
    
    for entry in "${symlinks[@]}"; do
        target="${entry%%:*}"
        source="${entry##*:}"
        target_name=$(basename "$target")
        
        if [ -L "$target" ]; then
            actual=$(readlink "$target")
            if [ "$actual" = "$source" ]; then
                echo -e "  ${GREEN}✓${NC} $target_name -> $source"
            else
                echo -e "  ${YELLOW}⚠${NC} $target_name -> $actual (expected: $source)"
                all_ok=false
            fi
        elif [ -e "$target" ]; then
            echo -e "  ${RED}✗${NC} $target_name exists but is not a symlink"
            all_ok=false
        else
            echo -e "  ${RED}✗${NC} $target_name does not exist"
            all_ok=false
        fi
    done
    echo ""
    
    if $all_ok; then
        success "All symlinks are correctly configured!"
    else
        warning "Some symlinks need attention. Re-run bootstrap.sh to fix."
    fi
}

verify_all_symlinks

###############################################################################
# Final Steps
###############################################################################
echo ""
if $VERIFY_ONLY; then
    success "✨ Symlink verification complete! ✨"
elif $FIX_SYMLINKS; then
    success "✨ Symlinks fixed! ✨"
    echo ""
    info "Restart your terminal or run: source ~/.zshrc"
else
    success "✨ Dotfiles setup complete! ✨"
    echo ""
    info "Next steps:"
    echo "  1. Restart your terminal or run: source ~/.zshrc"
    echo "  2. If using iTerm2, restart it to load new preferences"
    echo "  3. Open Neovim and run :PackerSync to install plugins"
    echo "  4. Review your Git configuration and update user email/name if needed"
    echo ""
    info "Your old configurations have been backed up with .backup extension"
fi
echo ""
info "Useful commands:"
echo "  Verify symlinks:  $DOTFILES_DIR/bootstrap.sh --verify"
echo "  Fix symlinks:     $DOTFILES_DIR/bootstrap.sh --fix-symlinks"
echo ""
