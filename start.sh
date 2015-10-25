#!/bin/bash

DEBUG=""

if [ "$1" == "debug" ];
then
    DEBUG=">> /home/botmaster/logs/pluginbots.log 2>&1"
    mkdir /home/botmaster/logs
fi

### Kill all running mpd instances (of the user botmaster) ... ###
echo "Killing running mpd instances of user \"$LOGNAME\""
killall mpd > /dev/null 2>&1
sleep 2
killall mpd > /dev/null 2>&1


### Start needed mpd instances for botmaster ###
mpd /home/botmaster/mpd1/mpd.conf
#mpd /home/botmaster/mpd2/mpd.conf
#mpd /home/botmaster/mpd3/mpd.conf


# Do an update of youtube-dl on every start as there are very often updates.
if [ -f /home/botmaster/src/youtube-dl ]; then
    echo "Updating youtube-dl..."
    /home/botmaster/src/youtube-dl -U
fi


### Kill running mumble-ruby-pluginbots (of the user botmaster) ###
echo "Killing running ruby scripts of user \"$LOGNAME\""
killall ruby > /dev/null 2>&1
sleep 1
killall ruby > /dev/null 2>&1

source ~/.rvm/scripts/rvm
rvm use @bots

### We need to be in this directory in order to start the bot(s).
cd /home/botmaster/src/mumble-ruby-pluginbot/

### Start Mumble-Ruby-Bots - MPD instances must already be running. ###
# Bot 1
tmux new-session -d -n bot1 "LD_LIBRARY_PATH=/home/botmaster/src/celt/lib/ ruby /home/botmaster/src/mumble-ruby-pluginbot/pluginbot.rb --config=/home/botmaster/src/bot1_conf.rb$DEBUG"

# Bot 2
#tmux new-session -d -n bot2 "LD_LIBRARY_PATH=/home/botmaster/src/celt/lib/ ruby /home/botmaster/src/mumble-ruby-pluginbot/pluginbot.rb --config=/home/botmaster/src/bot2_conf.rb$DEBUG"

# Bot 3
#tmux new-session -d -n bot3 "LD_LIBRARY_PATH=/home/botmaster/src/celt/lib/ ruby /home/botmaster/src/mumble-ruby-pluginbot/pluginbot.rb --config=/home/botmaster/src/bot3_conf.rb$DEBUG"




### Optional: Clear playlist, add music and play it; three lines for every bot ###
# Bot 1
# Comment out the next tree lines if you don't want to always listen to the radio.
mpc -p 7701 add http://ogg.theradio.cc/
mpc -p 7701 play

# Bot 2
#mpc -p 7702 clear
#mpc -p 7702 add http://streams.radio-gfm.net/rockpop.ogg.m3u
#mpc -p 7702 play

# Bot 3
#mpc -p 7703 clear
#mpc -p 7703 add http://stream.url.tld/musik.ogg
#mpc -p 7703 play

cat <<EOF



Your bot(s) should now be connected to the configured Mumble server.
Have fun with mumble-ruby-pluginbot :)

If something doesn't work, start this script with the additional parameter debug:
~/src/mumble-ruby-pluginbot/start.sh debug

Then take a look into the logfile within /home/botmaster/logs/.

Also make sure to run this script as user botmaster if you used the official installation documentation and DO NOT RUN THIS SCRIPT AS root.

Also please reread the official documentation at http://wiki.natenom.com/w/Mumble-Ruby-Pluginbot
EOF

