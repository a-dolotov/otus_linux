#!/bin/expect -f
set timeout -1
spawn /home/vagrant/atlassian-jira-software-8.5.1-x64.bin
send "y\r"
send "o\r"
send "1\r"
send "i\r"
send "y\r"
expect eof
