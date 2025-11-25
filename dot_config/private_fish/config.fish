set fish_greeting
set -g fish_key_bindings fish_vi_key_bindings

if status is-interactive
    # Commands to run in interactive sessions can go here
end

starship init fish | source

# Aliases
alias c='clear'
alias v='nvim'

alias l='exa --icons -l --group-directories-first'
alias ll='exa --icons -la --group-directories-first'
alias lt='exa --icons -l --tree -L 3 --group-directories-first'

alias gst='git status'

# Path modifications
set -gx PATH /home/ids/.cargo/bin $PATH
