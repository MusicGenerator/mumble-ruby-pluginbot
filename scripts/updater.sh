#!/bin/bash --login

INPUT=/tmp/menu.sh.$$
OUTPUT=/tmp/output.sh.$$
YAML_UPDATE_DONE="$HOME/src/.update_to_yaml_done"
trap "rm $OUTPUT; rm $INPUT; exit" SIGHUP SIGINT SIGTERM

if [ ! -f "$(which dialog 2>/dev/null)" ]; then
    echo -en "\n\nYou must install \"dialog\" on your system in order to use this updater.\n"
    exit 1
fi

# Check whether this installation is one with deprecated ruby configuration files.
# If so display a big warning that a manual update must be done for the configuration file of the bot.
function upgrade_to_yaml() {
    if [ -f "$HOME/src/bot1_conf.yml" ] &&  [ -f "${YAML_UPDATE_DONE}" ];
    then
        # Update was already done and new YAML config beside the old .rb config was created
        # Do not continue until the old rb configuration file was removed.

        if [ -f "$HOME/src/bot1_conf.rb" ];
        then
            echo -en "\n\n\nWARNING: REMOVE the old ruby style configuration file \"$HOME/src/bot1_conf.rb\".\n\n"
            echo -en "The updater won't run as long as this file was not removed.\n\n"
            exit 15
        fi
    else
        # Neither the new overwrite config bot1_conf.yml does exist nor the YAML_UPDAT_DONE file.

        # Check whether we have an installation that already has YAML configuration files.
        if [ -f $HOME/src/mumble-ruby-pluginbot/pluginbot_conf.yml ];
        then
            # This installation already has a YAML config file, so it was updated.

            # Create a new overwrite config beside the old .rb config but make sure not to overwrite an existing one.
            if [ ! -f $HOME/src/bot1_conf.rb ];
            then
                cp $HOME/src/mumble-ruby-pluginbot/scripts/overwrite_conf.yml $HOME/src/bot1_conf.yml
                touch "${YAML_UPDATE_DONE}" # To know later that we already did this ... :)
            fi

            cat<<EOF

            WARNING: The format for configuration files has been changed from ruby style to YAML style.

            You need to manually adapt the changes from
                $HOME/src/bot1_conf.rb
            into
                $HOME/src/bot1_conf.yml

            When you finished that please remove the file $HOME/src/bot1_conf.rb or rename it.

            Do the same for every additional bot in your installation.

            Then run this updater again and then restart your bot or the complete system.
EOF
            exit 15
        fi
    fi
}

upgrade_to_yaml

function update_error() {
    echo -ne "\n\n\nERROR: Something went wrong, please verify the updates via the commandline.\n\n\n\n"
    echo -ne "\nThe error occured while updating \"${1}\\n\n"
    exit 127
}

function done_wait() {
    echo -en "\n\n\nUpdate done; press enter to continue..."
    read _a
}

function update_pluginbot() {
    echo "Updating the mumble-ruby-pluginbot from github..."
    cd ~/src/mumble-ruby-pluginbot/
    git pull origin master
    return 0
}

function update_mpd() {
    echo -en "Not yet implemented :)\nThough in most cases not needed because we use the distributions mpd package."
    return 0
}

function update_youtubedl() {
    ~/src/youtube-dl -U
    return 0
}

function update_celt-gem() {
    cd ~/src/celt-ruby
    git pull origin master
    rvm use @bots
    gem build celt-ruby.gemspec
    rvm @bots do gem install celt-ruby
    return 0
}

function update_opus-gem() {
    cd ~/src/opus-ruby
    git pull origin master
    rvm use @bots
    gem build opus-ruby.gemspec
    rvm @bots do gem install opus-ruby
    return 0
}

function update_mumble-ruby-gem() {
    cd ~/src/mumble-ruby
    git pull origin master
    rvm use @bots
    gem build mumble-ruby.gemspec
    rvm @bots do gem install mumble-ruby-*.gem
    return 0
}

function update_mumble-mpd-gem() {
    rvm @bots do gem install ruby-mpd
    return 0
}

function update_celt-libs() {
    cd ~/src/celt-0.7.0
    git pull origin master
    ./autogen.sh
    ./configure --prefix=$HOME/src/celt
    make
    make install
    return 0
}

function update_dependencies() {
    cd ~/src
    rvm use @bots
    rvm @bots do gem install crack
}

while true
do
    dialog --clear --menu "Select Option" 15 50 12\
    a "Update everything bot related at once..."\
    c "Edit bot configuration file..."\
    1 "Update only Mumble-Ruby-Pluginbot"\
    2 "Update only MPD"\
    3 "Update only youtube-dl script"\
    4 "Update only CELT gem"\
    5 "Update only OPUS gem"\
    6 "Update only Mumble-Ruby gem"\
    7 "Update only MPD gem"\
    9 "Update only CELT libs" \
    0 "Exit" 2>"${INPUT}"

    menuitem=$(<"${INPUT}")

    case $menuitem in
            a)
                update_pluginbot
                update_mpd
                update_youtubedl
                update_celt-gem
                update_opus-gem
                update_mumble-ruby-gem
                update_mumble-mpd-gem
                update_celt-libs
                update_dependencies
            ;;
            1)
                update_pluginbot
            ;;
            2)
                update_mpd
            ;;
            3)
                update_youtubedl
            ;;
            4)
                update_celt-gem
            ;;
            5)
                update_opus-gem
            ;;
            6)
                update_mumble-ruby-gem
            ;;
            7)
                update_mumble-mpd-gem
            ;;
            c)
                nano ~/src/bot1_conf.rb
            ;;
            9)
                update_celt-libs
            ;;
            0)
                break
            ;;
    esac
done
