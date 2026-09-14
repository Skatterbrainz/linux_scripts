# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
	*i*) ;;
	  *) return;;
esac

blk='\[\033[01;30m\]'   # Black
red='\[\033[01;31m\]'   # Red
grn='\[\033[01;32m\]'   # Green
ylw='\[\033[01;33m\]'   # Yellow
blu='\[\033[01;34m\]'   # Blue
pur='\[\033[01;35m\]'   # Purple
cyn='\[\033[01;36m\]'   # Cyan
wht='\[\033[01;37m\]'   # White
clr='\[\033[00m\]'      # Reset

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000
HISTTIMEFORMAT="%F %T "

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
	debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
	xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
	if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
	else
	color_prompt=
	fi
fi

if [ "$color_prompt" = yes ]; then
	PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
	PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
	PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
	;;
*)
	;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
	test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
	alias ls='ls --color=auto'
	#alias dir='dir --color=auto'
	#alias vdir='vdir --color=auto'

	alias grep='grep --color=auto'
	alias fgrep='fgrep --color=auto'
	alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias lx='find . -maxdepth 1 -type f -executable'
alias lxx='find . -type f -executable'
alias ..='cd ..'
alias home='cd ~'
alias c='clear'
alias jan='cal -m 01'
alias feb='cal -m 02'
alias mar='cal -m 03'
alias apr='cal -m 04'
alias may='cal -m 05'
alias jun='cal -m 06'
alias jul='cal -m 07'
alias aug='cal -m 08'
alias sep='cal -m 09'
alias oct='cal -m 10'
alias nov='cal -m 11'
alias dec='cal -m 12'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
	. ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
	. /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
	. /etc/bash_completion
  fi
fi

export OPENAI_API_KEY=""
export GEMINI_API_KEY=""
export ANTHROPIC_API_KEY=""
export TAVILY_API_KEY=""
export PSGALLERY_KEY=""

function update-computer() {
	set -uo pipefail

	DRY_RUN=true
	case "${1:-}" in
		"")
			;;
		--apply|-y)
			DRY_RUN=false
			;;
		--dry-run|-n)
			DRY_RUN=true
			;;
		-h|--help)
			echo "Usage: $0 [--apply|-y]"
			echo "  (no argument)   Dry run — list pending updates, change nothing (default)"
			echo "  --apply, -y     Actually run the updates"
			echo "  --dry-run, -n   Explicitly request a dry run (same as no argument)"
			exit 0
			;;
		*)
			echo "Error: unrecognized argument '$1'" >&2
			echo "Usage: $0 [--apply|-y]" >&2
			exit 1
			;;
	esac

	if $DRY_RUN; then
		echo "Dry run mode (default) — listing pending updates only, no changes will be made."
		echo "Pass --apply to actually run updates."
	fi

	log() {
		printf '\n\033[1;34m==> %s\033[0m\n' "$1"
	}

	require_root_hint() {
		if [[ $EUID -ne 0 ]] && ! $DRY_RUN; then
			echo "Note: not running as root — this step may prompt for sudo or fail." >&2
		fi
	}

	UPDATED_ANYTHING=false

	# --- APT (Debian/Ubuntu) ---
	if command -v apt-get &>/dev/null; then
		log "APT detected"
		require_root_hint
		sudo apt-get update -qq
		if $DRY_RUN; then
			echo "Packages that would be upgraded:"
			apt list --upgradable 2>/dev/null | tail -n +2
		else
			sudo apt-get upgrade -y
			sudo apt-get autoremove -y
		fi
		UPDATED_ANYTHING=true
	fi

	# --- DNF (Fedora / modern RHEL) ---
	if command -v dnf &>/dev/null; then
		log "DNF detected"
		require_root_hint
		if $DRY_RUN; then
			echo "Packages that would be upgraded:"
			sudo dnf check-update || true   # exit code 100 means updates are available; not an error
		else
			sudo dnf upgrade --refresh -y
		fi
		UPDATED_ANYTHING=true

	# --- YUM (older RHEL/CentOS) — only if dnf isn't already handling it ---
	elif command -v yum &>/dev/null; then
		log "YUM detected"
		require_root_hint
		if $DRY_RUN; then
			echo "Packages that would be upgraded:"
			sudo yum check-update || true   # exit code 100 means updates are available; not an error
		else
			sudo yum update -y
		fi
		UPDATED_ANYTHING=true
	fi

	# --- Zypper (openSUSE) ---
	if command -v zypper &>/dev/null; then
		log "Zypper detected"
		require_root_hint
		sudo zypper refresh
		if $DRY_RUN; then
			echo "Packages that would be upgraded:"
			zypper list-updates
		else
			sudo zypper update -y
		fi
		UPDATED_ANYTHING=true
	fi

	# --- Pacman (Arch/Manjaro) ---
	if command -v pacman &>/dev/null; then
		log "Pacman detected"
		require_root_hint
		if $DRY_RUN; then
			echo "Packages that would be upgraded:"
			if command -v checkupdates &>/dev/null; then
				checkupdates
			else
				echo "(install 'pacman-contrib' for a safe, non-syncing 'checkupdates' preview;"
				echo " falling back to 'pacman -Qu', which only reflects the last synced database)"
				pacman -Qu || echo "No updates found in the local package database."
			fi
		else
			sudo pacman -Syu --noconfirm
		fi
		UPDATED_ANYTHING=true
	fi

	# --- Flatpak ---
	if command -v flatpak &>/dev/null; then
		log "Flatpak detected"
		if $DRY_RUN; then
			echo "Flatpak apps/runtimes that would be updated:"
			flatpak remote-ls --updates
		else
			flatpak update -y
		fi
		UPDATED_ANYTHING=true
	fi

	# --- Snap ---
	if command -v snap &>/dev/null; then
		log "Snap detected"
		if $DRY_RUN; then
			echo "Snaps that would be refreshed:"
			snap refresh --list
		else
			sudo snap refresh
		fi
		UPDATED_ANYTHING=true
	fi

	# --- Flag if nothing was found ---
	if ! $UPDATED_ANYTHING; then
		echo "No supported package managers (apt, dnf, yum, zypper, pacman, flatpak, snap) were found."
		exit 1
	fi

	if $DRY_RUN; then
		log "Dry run complete. Re-run with --apply to install the above."
	else
		log "Done."
	fi
}

function find-largest-files() {
	du -h -x -s -- * | sort -r -h | head -20;
}

function git_branch() {
    if [ -d .git ] ; then
        printf "%s" "($(git branch 2> /dev/null | awk '/\*/{print $2}'))";
    fi
}

function bash_prompt(){
    PS1='${debian_chroot:+($debian_chroot)}'${blu}'$(git_branch)'${pur}' \W'${grn}' \$ '${clr}
}

if [ -d "$HOME/.cargo" ]; then
    . "$HOME/.cargo/env"
fi

if [ -d "$HOME/.local/state/warp-terminal" ]; then
    export PATH="$HOME/.local/state/warp-terminal:$PATH"
fi
