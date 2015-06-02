#!/bin/bash

### Kill all running mpd instances (of the user botmaster) ... ###
echo "Killing running mpd instances of user \"$LOGNAME\""
killall mpd > /dev/null 2>&1
sleep 2
killall mpd > /dev/null 2>&1




### Start needed mpd instances for botmaster ###
mpd /home/botmaster/mpd1/mpd.conf
#mpd /home/botmaster/mpd2/mpd.conf
#mpd /home/botmaster/mpd3/mpd.conf




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
tmux new-session -d -n bot1 'LD_LIBRARY_PATH=/home/botmaster/src/celt/lib/ ruby /home/botmaster/src/mumble-ruby-pluginbot/pluginbot.rb --config=/home/botmaster/src/bot1_conf.rb --certdir /home/botmaster/src/certs'

# Bot 2
#tmux new-session -d -n bot2 'LD_LIBRARY_PATH=/home/botmaster/src/celt/lib/ ruby /home/botmaster/src/mumble-ruby-pluginbot/pluginbot.rb --config=/home/botmaster/src/bot2_conf.rb --certdir /home/botmaster/src/certs'

# Bot 3
#tmux new-session -d -n bot3 'LD_LIBRARY_PATH=/home/botmaster/src/celt/lib/ ruby /home/botmaster/src/mumble-ruby-pluginbot/pluginbot.rb --config=/home/botmaster/src/bot3_conf.rb --certdir /home/botmaster/src/certs'




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
