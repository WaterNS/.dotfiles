# Show Full Path in Bash Prompt
#export PS1='\u@\h \W \$ '
export PS1="\[\033[38m\]\u@\h\[\033[32m\] \w \[\033[31m\]\`ruby -e \"print (%x{git branch 2> /dev/null}.split(%r{\n}).grep(/^\*/).first || '').gsub(/^\* (.+)$/, '(\1) ')\"\`\[\033[37m\]$\[\033[00m\] "

alias ls='ls -alhG'

# Source bash-powerline
#source ~/.bash-powerline.sh

# youtube-dl shorthand alias and auto retry
ytdl () { while ! youtube-dl "$1" -c --socket-timeout 5; do echo DISCONNECTED; sleep 5; done; }

