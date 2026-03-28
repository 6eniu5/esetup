set -gx XDG_CONFIG_HOME $HOME/.config
set -gx EDITOR nvim
set -gx GIT_EDITOR nvim
set -gx DOTFILES $HOME/6eniu5/dotfiles
set -q CU_OWNER; or set -gx CU_OWNER $USER
set -q AWS_PROFILE; or set -gx AWS_PROFILE clickup-app-backend-local
set -gx PNPM_HOME $HOME/Library/pnpm

test -d $HOME/.local/bin; and fish_add_path $HOME/.local/bin
test -d $HOME/.local/scripts; and fish_add_path $HOME/.local/scripts
test -d $HOME/.cargo/bin; and fish_add_path $HOME/.cargo/bin
test -d $HOME/.bun/bin; and fish_add_path $HOME/.bun/bin
test -d $PNPM_HOME; and fish_add_path $PNPM_HOME

if test -x /opt/homebrew/bin/brew
  eval (/opt/homebrew/bin/brew shellenv)
else if test -x /usr/local/bin/brew
  eval (/usr/local/bin/brew shellenv)
end

set -l brew_prefix (brew --prefix 2>/dev/null)
if test -n "$brew_prefix" -a -d "$brew_prefix/opt/gnu-sed/libexec/gnubin"
  fish_add_path --prepend "$brew_prefix/opt/gnu-sed/libexec/gnubin"
end

if test -z "$JAVA_HOME" -a -x /usr/libexec/java_home
  set -gx JAVA_HOME (/usr/libexec/java_home -v 21 2>/dev/null)
  test -n "$JAVA_HOME"; and fish_add_path "$JAVA_HOME/bin"
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

command -v fnm >/dev/null 2>&1; and fnm env --use-on-cd --shell fish | source
command -v mise >/dev/null 2>&1; and mise activate fish | source
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

function gwta --description 'Git worktree add: gwta <ticket-id> <name> [base-branch]'
  if test (count $argv) -lt 2 -o (count $argv) -gt 3
    echo "Usage: gwta <ticket-id> <name> [base-branch]"
    return 1
  end
  set -l ticket $argv[1]
  set -l name $argv[2]
  set -l base $argv[3]
  if test -z "$base"
    set base (git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/||')
  end
  if test -z "$base"
    echo "Error: Could not detect default branch. Pass it explicitly: gwta <ticket> <name> origin/master"
    return 1
  end
  set -l branch "mowens/$ticket/$name"
  set -l wt_path "./mowens/$ticket/$name"
  /usr/bin/git worktree add -b "$branch" "$wt_path" "$base"
end

function get_dd_key --description 'Fetch DataDog API key from 1Password (cached)'
  if test -z "$DD_API_KEY"
    echo "Fetching DataDog key from 1Password..."
    set -gx DD_API_KEY (op read "op://Engineering/DataDog Frontend API key/password")
  end
  echo $DD_API_KEY
end

alias refresh_gh_token 'set -gx GITHUB_TOKEN (gh auth token)'
