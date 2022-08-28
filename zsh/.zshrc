
HISTSIZE=1000000
SAVEHIST=1000000

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="/Users/yogeshshelke/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themesi
# ZSH_THEME="robbyrussell"
ZSH_THEME="powerlevel10k/powerlevel10k"
# ZSH_THEME="spaceship"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
aws
#colored-man.pages
fzf
git
github
zsh-autosuggestions
# zsh-syntax-highlighting
)

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
# 114 autoload -U +X bashcompinit && bashcompinit


# Adding Aias---
alias kx=kubectx
alias kn=kubens
alias kc=kubectl
alias tf=terraform
alias tg=terragrunt
alias lvim=/Users/yogeshshelke/.local/bin/lvim
alias yvim=/Users/yogeshshelke/.local/bin/lvim
alias awsp='source _awsp ; aws sso login'
# alias alo='aws sso login'

setopt HIST_IGNORE_ALL_DUPS

source $ZSH/oh-my-zsh.sh
source /usr/local/etc/autojump.sh
source <(kubectl completion zsh)

ax() { aws-vault exec “$@“; }

source /Users/yogeshshelke/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

source "/usr/local/opt/kube-ps1/share/kube-ps1.sh"
PS1='$(kube_ps1)'$PS1

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

#source for asdf
. /usr/local/opt/asdf/libexec/asdf.sh 

complete -o nospace -C /usr/local/bin/t erraform terraform

#PATH
export PATH=“/usr/local/opt/curl/bin:$PATH”
export PATH="$(brew --prefix)/bin/:~/.bin:$PATH"
export GPG_TTY=$(tty)
export EDITOR=vim

export KUBE_CONFIG_PATH=$HOME/.kube/config
export AWS_CONFIG_FILE=$HOME/.aws/config
export AWS_SHARED_CREDENTIALS_FILE=$HOME/.aws/sso/cache


# Dope Env initialization
# eval "$(direnv hook zsh)"
# export PATH="/Users/yogeshshelke/git/dope-env/bin:$PATH"
# export ENVIRONMENTS="test dev qa prod mgmt"
# test -f /Users/yogeshshelke/git/dope-env/env.sh && eval "$(/Users/yogeshshelke/git/dope-env/env.sh aliases)"
# export PATH="/usr/local/opt/kubernetes-cli@1.22/bin:$PATH"
