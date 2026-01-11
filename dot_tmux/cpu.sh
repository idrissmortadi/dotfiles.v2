# ~/.tmux/cpu.sh
#!/bin/sh
ps -A -o %cpu | awk '{s+=$1} END {printf "%.0f%%", s}'
