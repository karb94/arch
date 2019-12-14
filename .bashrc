# If not running interactively, don't do anything
[[ $- != *i* ]] && return
# Have a common history file
shopt -s histappend

# Update history file after every command and separate
# prompt from last command with a blank line
PROMPT_COMMAND="history -a; printf '\n'"

# Define your command prompt
PS1='\e[0;36m\u:\e[0;32m\w/\e[m\n$ '


# If .alias file exists, source it 
[ -f ~/.alias ] && source ~/.alias 
# If .fzf.bash file exists, source it 
[ -f ~/.fzf.bash ] && source ~/.fzf.bash 

# [[ ":$PATH:" != *":/path/to/add:"* ]] && PATH="${PATH:/path/to/add"
