# Source bash-powerline
source ~/.bash-powerline.sh

# Show Full Path in Bash Prompt
PS1='\W\$ '

# youtube-dl shorthand alias and auto retry
ytdl () { while ! youtube-dl "$1" -c --socket-timeout 5; do echo DISCONNECTED; sleep 5; done; }

