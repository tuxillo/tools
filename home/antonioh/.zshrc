# The following lines were added by compinstall

zstyle ':completion:*' completer _complete _ignored
zstyle :compinstall filename '/home/antonioh/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall
# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
unsetopt beep
bindkey -e
# End of lines configured by zsh-newuser-install


# From http://stackoverflow.com/questions/1128496/to-get-a-prompt-which-indicates-git-branch-in-zsh (Christopher)
setopt prompt_subst
autoload -Uz vcs_info
zstyle ':vcs_info:*' stagedstr 'M'
zstyle ':vcs_info:*' unstagedstr 'M'
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' actionformats '%F{5}[%F{2}%b%F{3}|%F{1}%a%F{5}]%f '
zstyle ':vcs_info:*' formats \
       '%F{5}[%F{2}%b%F{5}] %F{2}%c%F{3}%u%f'
zstyle ':vcs_info:git*+set-message:*' hooks git-untracked
zstyle ':vcs_info:*' enable git
+vi-git-untracked() {
    if [[ $(git rev-parse --is-inside-work-tree 2> /dev/null) == 'true' ]] && \
	   [[ $(git ls-files --no-empty-directory --other --directory --exclude-standard | sed q | wc -l | tr -d ' ') == 1 ]] ; then
	hook_com[unstaged]+='%F{1}??%f'
    fi
}


precmd () { vcs_info }
PROMPT='%F{5}[%F{2}%n%F{5}] %F{3}%3~ ${vcs_info_msg_0_} %f%# '
