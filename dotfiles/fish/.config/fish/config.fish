set -gx XDG_CONFIG_HOME $HOME/.config
set -gx EDITOR nvim
set -gx GIT_EDITOR nvim
set -gx DOTFILES $HOME/dotfiles

test -d $HOME/.local/bin; and fish_add_path $HOME/.local/bin
test -d $HOME/.local/scripts; and fish_add_path $HOME/.local/scripts
test -d $HOME/.cargo/bin; and fish_add_path $HOME/.cargo/bin
test -d $HOME/.bun/bin; and fish_add_path $HOME/.bun/bin

if test -x /opt/homebrew/bin/brew
  eval (/opt/homebrew/bin/brew shellenv)
else if test -x /usr/local/bin/brew
  eval (/usr/local/bin/brew shellenv)
end

set -l brew_prefix (brew --prefix 2>/dev/null)
if test -n "$brew_prefix" -a -d "$brew_prefix/opt/gnu-sed/libexec/gnubin"
  fish_add_path --prepend "$brew_prefix/opt/gnu-sed/libexec/gnubin"
end

fish_vi_key_bindings

function fish_greeting
end

alias vim nvim
alias ls eza
alias cat 'bat --paging=never'

function la --wraps=ls --wraps=eza --description 'List contents of directory using eza grid'
  eza --grid --icons -a --long --header --accessed --group-directories-first $argv
end

function ll --wraps=ls --wraps=eza --description 'List contents of directory using eza tree'
  eza --tree --level=2 -a --long --header --accessed --git $argv
end

function lla --wraps=ls --wraps=eza --description 'List contents of directory using eza tree'
  eza --tree --level=1 -a --long --header --accessed --group-directories-first $argv
end

function lll --wraps=ls --wraps=eza --description 'List contents of directory using eza tree'
  eza --tree --level=2 -a --long --header --accessed --group-directories-first $argv
end

function llll --wraps=ls --wraps=eza --description 'List contents of directory using eza tree'
  eza --tree --level=3 -a --long --header --accessed --group-directories-first $argv
end

bind \cf 'tmux-sessionizer; commandline -f repaint'
bind -M insert \cf 'tmux-sessionizer; commandline -f repaint'

bind \eh 'tmux-sessionizer -s 0; commandline -f repaint'
bind -M insert \eh 'tmux-sessionizer -s 0; commandline -f repaint'
bind \et 'tmux-sessionizer -s 1; commandline -f repaint'
bind -M insert \et 'tmux-sessionizer -s 1; commandline -f repaint'
bind \en 'tmux-sessionizer -s 2; commandline -f repaint'
bind -M insert \en 'tmux-sessionizer -s 2; commandline -f repaint'
bind \es 'tmux-sessionizer -s 3; commandline -f repaint'
bind -M insert \es 'tmux-sessionizer -s 3; commandline -f repaint'

test -f "$HOME/.cargo/env.fish"; and source "$HOME/.cargo/env.fish"

command -v fnm >/dev/null 2>&1; and fnm env | source
command -v atuin >/dev/null 2>&1; and atuin init fish | source
command -v zoxide >/dev/null 2>&1; and zoxide init fish | source
command -v starship >/dev/null 2>&1; and starship init fish | source

if test -f /opt/homebrew/Caskroom/miniconda/base/etc/fish/conf.d/conda.fish
  source /opt/homebrew/Caskroom/miniconda/base/etc/fish/conf.d/conda.fish
else if test -f /usr/local/Caskroom/miniconda/base/etc/fish/conf.d/conda.fish
  source /usr/local/Caskroom/miniconda/base/etc/fish/conf.d/conda.fish
end

if test -d $HOME/.sdkman
  set -gx SDKMAN_DIR $HOME/.sdkman
end
