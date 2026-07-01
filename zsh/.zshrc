# Zinit installation path
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Install zinit if not already present
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone git@github.com:zdharma-continuum/zinit.git "$ZINIT_HOME"

# Source Zinit plugin manager
source "${ZINIT_HOME}/zinit.zsh"

# Vim mode
bindkey -v

# Change to Zsh's default readkey engine
ZVM_READKEY_ENGINE=$ZVM_READKEY_ENGINE_ZLE

# Plugins
zinit ice depth=1
zinit light jeffreytse/zsh-vi-mode
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions

eval "$(starship init zsh)"

alias vim="nvim"
alias ls="exa --sort Name"
alias ll="exa --sort Name --long"
alias la="exa --sort Name --long --all"
alias lr="exa --sort Name --long --recurse"
alias lt="exa --sort Name --long --tree"

lazy_load_nvm() {
  unset -f node nvm
  export NVM_DIR=~/.nvm
  [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
}

node() {
  lazy_load_nvm
  node $@
}

nvm() {
  lazy_load_nvm
  node $@
}

export fpath=(~/.config/zsh $fpath)
autoload -U compinit && compinit

path=(
    $path
    ~/go/bin
    ~/go
    ~/code/scripts
    ~/.cargo/bin
    ~/.local/bin
    ~/.dotnet/tools
    ~/.local/share
    ~/.local/share/bob/nvim-bin/
    )

print_osc7() {
    if [ "$ZSH_SUBSHELL" -eq 0 ]; then
        printf "\033]7;file://$HOST/$PWD\033\\"
    fi
}
autoload -Uz add-zsh-hook
add-zsh-hook -Uz chpwd print_osc7
print_osc7


# Default browser
export BROWSER=librewolf
