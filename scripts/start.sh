#!/bin/bash --login

DEBUG=""
FIRST_START_FILE="$HOME/src/.first_start_done"

if [ "$1" == "debug" ];
then
    DEBUG=">> $HOME/logs/pluginbots.log 2>&1"
    mkdir $HOME/logs
fi


# Do an update of youtube-dl on every start as there are very often updates.
if [ -f $HOME/src/youtube-dl ]; then
    echo "Updating youtube-dl..."
    $HOME/src/youtube-dl -U
fi


### Kill running mumble-ruby-pluginbots (of the user botmaster) ###
echo "Killing running ruby scripts of user $USER"
killall ruby > /dev/null 2>&1
sleep 1
killall ruby > /dev/null 2>&1


### Kill all running mpd instances (of the user botmaster) ... ###
echo "Killing running mpd instances of user $USER"
killall mpd > /dev/null 2>&1
sleep 2
killall mpd > /dev/null 2>&1


### Start needed mpd instances for botmaster ###
mpd $HOME/mpd1/mpd.conf
#mpd $HOME/mpd2/mpd.conf
#mpd $HOME/mpd3/mpd.conf


source ~/.rvm/scripts/rvm
rvm use @bots

### We need to be in this directory in order to start the bot(s).
cd $HOME/src/mumble-ruby-pluginbot/

### Export enviroment variable for tmux
export HOME=$HOME

### Start Mumble-Ruby-Bots - MPD instances must already be running. ###
# Bot 1
tmux new-session -d -n bot1 "LD_LIBRARY_PATH=$HOME/src/celt/lib/ ruby $HOME/src/mumble-ruby-pluginbot/core/pluginbot.rb --config=$HOME/src/bot1_conf.yml$DEBUG"

# Bot 2
#tmux new-session -d -n bot2 "LD_LIBRARY_PATH=$HOME/src/celt/lib/ ruby $HOME/src/mumble-ruby-pluginbot/core/pluginbot.rb --config=$HOME/src/bot2_conf.yml$DEBUG"

# Bot 3
#tmux new-session -d -n bot3 "LD_LIBRARY_PATH=$HOME/src/celt/lib/ ruby $HOME/src/mumble-ruby-pluginbot/core/pluginbot.rb --config=$HOME/src/bot3_conf.yml$DEBUG"



### Optional: Clear playlist, add music and play it; three lines for every bot ###
# Bot 1
# Comment out the next tree lines if you don't want to always listen to the radio.
if [ ! -f "${FIRST_START_FILE}" ];
then
    mpc -p 7701 add http://ogg.theradio.cc/
    mpc -p 7701 play

    touch $HOME/src/.first_start_done
fi

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


_LOGGING/DEBUGGING_
  If something doesn't work, start this script with the additional parameter debug:
  ~/src/mumble-ruby-pluginbot/scripts/start.sh debug

  Then take a look into the logfile within $HOME/logs/.


_START AS APPROPRIATE USER_
  Make sure to run this script as user botmaster if you used the official
  installation documentation and DO NOT RUN THIS SCRIPT AS root.
  The official documentation can be found at https://wiki.natenom.com/w/Mumble-Ruby-Pluginbot


_UPDATE THE BOT (AND ITS DEPENDENCIES)_
  If you want to update the Mumble-Ruby-Pluginbot (and its dependencies) please
  run ~/src/mumble-ruby-pluginbot/scripts/updater.sh


_OFFICIAL DOCUMENTATION_
  Also please reread the official documentation at https://wiki.natenom.com/w/Mumble-Ruby-Pluginbot
  if you have further problems :)


_BUGS/WISHES/IDEAS_
  If you think you found a bug, have a wish for the bot or some ideas please don't
  hesitate to create an issue at https://github.com/dafoxia/mumble-ruby-pluginbot/issues


Have fun with the Mumble-Ruby-Pluginbot :)
EOF
