#!/bin/bash --login
while true; do
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
    
    source ~/.rvm/scripts/rvm
    rvm use @bots
    
    ### We need to be in this directory in order to start the bot(s).
    cd $HOME/src/mumble-ruby-pluginbot/core
    
    ### Export enviroment variable for tmux
    export HOME=$HOME
    
    LD_LIBRARY_PATH=$HOME/src/celt/lib/ ruby $HOME/src/mumble-ruby-pluginbot/core/pluginbot.rb --config=$HOME/src/bot1_conf.yml --mumblehost "$MUMBLE_HOST" --mumbleport "$MUMBLE_PORT" --name "$MUMBLE_USERNAME" --userpass "$MUMBLE_PASSWORD" --targetchannel "$MUMBLE_CHANNEL" --bitrate "$MUMBLE_BITRATE"
    sleep 5
done
