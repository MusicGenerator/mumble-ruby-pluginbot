#!/bin/bash --login

### Uncomment the next line if you get problems with special characters.
### Also make sure that the locale it is activated in /etc/locale.gen
#export LANG="en_US.UTF-8"

function show_help() {
    cat<<EOF
USAGE
  ${0} [OPTIONS]

OPTIONS
  stop                        Stop the bot(s)
  start                       Start the bot(s)
  restart                     Restart the bot(s)
  uytdl|updateytdl            Update youtube-dl
  log                         Show the bots log using tail
  status                      Show if bots are running or not
  -h|--help                   Show this help
EOF
}

function stop_bots_and_mpds() {
  ### Kill running tmux bot "windows" (of the user botmaster) ###
  echo "Killing tmux windows used by bots of user $USER"
  tmux kill-window -t bot1 > /dev/null 2>&1
  tmux kill-window -t bot2 > /dev/null 2>&1
  tmux kill-window -t bot3 > /dev/null 2>&1
  sleep 1
  tmux kill-window -t bot1 > /dev/null 2>&1
  tmux kill-window -t bot2 > /dev/null 2>&1
  tmux kill-window -t bot3 > /dev/null 2>&1

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
}

function update_youtubedl() {
  # Do an update of youtube-dl on every start as there are very often updates.
  if [ -f $HOME/src/youtube-dl ]; then
      echo "Updating youtube-dl..."
      $HOME/src/youtube-dl -U
  fi
}

function start_mpds() {
  ### Start needed mpd instances for botmaster ###
  mpd $HOME/mpd1/mpd.conf
  #mpd $HOME/mpd2/mpd.conf
  #mpd $HOME/mpd3/mpd.conf
}

function start_bots() {
  source ~/.rvm/scripts/rvm
  rvm use @bots

  ### We need to be in this directory in order to start the bot(s).
  cd $HOME/src/mumble-ruby-pluginbot/core

  ### Export enviroment variable for tmux
  export HOME=$HOME

  ### Start Mumble-Ruby-Bots - MPD instances must already be running. ###
  # Bot 1
  tmux new-session -d -n bot1 "while true; do LD_LIBRARY_PATH=$HOME/src/celt/lib/ ruby $HOME/src/mumble-ruby-pluginbot/core/pluginbot.rb --config=$HOME/src/bot1_conf.yml; sleep 10; done"

  # Bot 2
  #tmux new-session -d -n bot2 "while true; do LD_LIBRARY_PATH=$HOME/src/celt/lib/ ruby $HOME/src/mumble-ruby-pluginbot/core/pluginbot.rb --config=$HOME/src/bot2_conf.yml; sleep 10; done"

  # Bot 3
  #tmux new-session -d -n bot3 "while true; do LD_LIBRARY_PATH=$HOME/src/celt/lib/ ruby $HOME/src/mumble-ruby-pluginbot/core/pluginbot.rb --config=$HOME/src/bot3_conf.yml; sleep 10; done"

}

function show_disclaimer() {
  cat <<EOF



  Your bot(s) should now be connected to the configured Mumble server.


  _LOGGING/DEBUGGING_
    If something doesn't work, activate the debug config option in the main configuration file and restart the bot.

    Then take a look into the logfile within $HOME/logs/.


  _START AS APPROPRIATE USER_
    Make sure to run this script as user botmaster if you used the official
    installation documentation and DO NOT RUN THIS SCRIPT AS root.
    The official documentation can be found at http://mumble-ruby-pluginbot.readthedocs.io/


  _UPDATE THE BOT (AND ITS DEPENDENCIES)_
    If you want to update the Mumble-Ruby-Pluginbot (and its dependencies) please
    run ~/src/mumble-ruby-pluginbot/scripts/updater.sh


  _OFFICIAL DOCUMENTATION_
    Also please reread the official documentation at http://mumble-ruby-pluginbot.readthedocs.io/
    if you have further problems :)


  _BUGS/WISHES/IDEAS_
    If you think you found a bug, have a wish for the bot or some ideas please don't
    hesitate to create an issue at https://github.com/dafoxia/mumble-ruby-pluginbot/issues


  Have fun with the Mumble-Ruby-Pluginbot :)
EOF
}

function log() {
  TAIL_BIN="$(which tail)"
  echo -en "\n\nPress Ctrl+c to quit.\n"
  echo "Showing" ~/logs/*.log
  echo
  "${TAIL_BIN}" -f -n10 ~/logs/*.log
}

function status() {
  local _status=$(tmux list-windows 2> /dev/null | sed -r -e "s/.*(bot)[123].*/\1/g")

  if [ "${_status}" == "bot" ]; then
    echo "Bots are running"
    return 0
  else
    echo "Bots are not running"
    return 1
  fi
}

function parse() {
  if [ "$#" -le "0" ]; then
    show_help
  fi

  while [ "$#" -gt "0" ]; do
    case ${1} in
       status)
           status
           exit $?
           shift
           ;;
       start)
           update_youtubedl
           stop_bots_and_mpds
           start_mpds
           start_bots
           show_disclaimer
           shift
           ;;
       restart)
           update_youtubedl
           stop_bots_and_mpds
           start_mpds
           start_bots
           show_disclaimer
           shift
           ;;
       stop)
           stop_bots_and_mpds
           shift
           ;;
       -h|--help)
           show_help
           shift
           ;;
       uytdl|updateytdl)
           update_youtubedl
           shift
           ;;
       log)
           log
           shift
           ;;
       *)
          show_help
          shift
          ;;
      esac
    done
}

parse "$@"
