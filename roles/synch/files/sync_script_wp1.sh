#!/bin/bash
inotifywait -r -e modify,delete /home/admin1/ && rsync -avz --delete /home/admin1/ root@192.168.31.50:/home/admin1/ &
inotifywait -r -e modify,delete /home/admin1/ && rsync -avz --delete /home/admin1/ root@192.168.31.60:/home/admin1/ &
