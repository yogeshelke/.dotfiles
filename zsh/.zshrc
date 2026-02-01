# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console output (such as commands
# that call compinit) must go after this block.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

##### HISTORY #####
HISTSIZE=1000000
SAVEHIST=1000000
setopt HIST_IGNORE_ALL_DUPS

##### HOMEBREW (MUST BE FIRST) #####
if [[ $(uname -m) == 'arm64' ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    HOMEBREW_PREFIX="/opt/homebrew"
else
    eval "$(/usr/local/bin/brew shellenv)"
    HOMEBREW_PREFIX="/usr/local"
fi

##### OH-MY-ZSH #####
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  aws
  fzf
  git
  colored-man-pages
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

##### ALIASES #####
alias kx=kubectx
alias kn=kubens
alias k=kubectl
alias tf=terraform
alias tg=terragrunt
alias lvim="$HOME/.local/bin/lvim"
alias yvim="$HOME/.local/bin/lvim"
alias awsp='source _awsp ; aws sso login'
alias z='zellij --layout ~/.config/zellij_layout/terraform_proj.kdl'
alias k9s-update-skin='curl -o ~/.config/k9s/skins/nord.yaml https://raw.githubusercontent.com/derailed/k9s/master/skins/nord.yaml && echo "Nord skin updated"'

##### TOOLING #####
source "$HOMEBREW_PREFIX/etc/autojump.sh"
source "$HOMEBREW_PREFIX/opt/asdf/libexec/asdf.sh"
# kube-ps1 not needed - powerlevel10k has native kubecontext segment (see ~/.p10k.zsh)
# source "$HOMEBREW_PREFIX/opt/kube-ps1/share/kube-ps1.sh"

# kubectl completions - cached for faster startup
# Old (slower): source <(kubectl completion zsh)
ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
[[ -d "$ZSH_CACHE_DIR" ]] || mkdir -p "$ZSH_CACHE_DIR"
if [[ ! -f "$ZSH_CACHE_DIR/kubectl.zsh" ]] || [[ $(which kubectl) -nt "$ZSH_CACHE_DIR/kubectl.zsh" ]]; then
    kubectl completion zsh > "$ZSH_CACHE_DIR/kubectl.zsh"
fi
source "$ZSH_CACHE_DIR/kubectl.zsh"

##### COMPLETIONS #####
# Optimized compinit - only rebuild cache once per day
# Old (slower):
# autoload -Uz compinit
# compinit
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

##### PATH (minimal & ordered) #####
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.krew/bin:$PATH"
export PATH="$HOMEBREW_PREFIX/opt/openjdk/bin:$PATH"
export PATH="$HOME/kafka_2.13-3.9.1/bin:$PATH"

##### JAVA / KAFKA #####
export CLASSPATH="$HOME/kafka_2.13-3.9.1/bin/aws-msk-iam-auth-1.1.8-all.jar"

##### ENV #####
export GPG_TTY=$(tty)
export EDITOR=vim
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export XDG_CONFIG_HOME="$HOME/.config"

##### KUBERNETES #####
export KUBECONFIG=$(echo $(ls ~/.kube/config*) | awk '{ gsub(/ /,":");print}')
export KUBE_CONFIG_PATHS=$KUBECONFIG

##### AWS #####
export AWS_CONFIG_FILE="$HOME/.aws/config"
export AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/sso/cache"

##### POWERLEVEL10K #####
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Note: zsh-syntax-highlighting is loaded via Oh-My-Zsh plugins above

