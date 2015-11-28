#!/bin/bash --login
 
INPUT=/tmp/menu.sh.$$
OUTPUT=/tmp/output.sh.$$
trap "rm $OUTPUT; rm $INPUT; exit" SIGHUP SIGINT SIGTERM

if [ ! -f "$(which dialog 2>/dev/null)" ]; then
    echo -en "\n\nYou must install \"dialog\" on your system in order to use this updater.\n"
    exit 1
fi

function done_wait() {
    echo -en "\n\n\nUpdate done; press enter to continue..."
    read _a
}

function update_pluginbot() {
    echo "Updating the mumble-ruby-pluginbot from github..."
    cd ~/src/mumble-ruby-pluginbot/
    git pull origin master
    done_wait
}

function update_mpd() {
    echo -en "Not yet implemented :)\nThough in most cases not needed because we use the distributions mpd package."
    done_wait
}

function update_youtubedl() {
    ~/src/youtube-dl -U
    done_wait
}

function update_celt-gem() {
    cd ~/src/celt-ruby
    git pull
    rvm use @bots
    gem build celt-ruby.gemspec
    rvm @bots do gem install celt-ruby
    done_wait
}

function update_opus-gem() {
    cd ~/src/opus-ruby
    git pull
    rvm use @bots
    gem build opus-ruby.gemspec
    rvm @bots do gem install opus-ruby
    done_wait
}

function update_mumble-ruby-gem() {
    cd ~/src/mumble-ruby
    git pull
    rvm use @bots
    gem build mumble-ruby.gemspec
    rvm @bots do gem install mumble-ruby-*.gem
    done_wait
}

function update_mumble-mpd-gem() {
    rvm @bots do gem install ruby-mpd
    done_wait
}

function update_celt-libs() {
    cd ~/src/celt-0.7.0
    git pull
    ./autogen.sh
    ./configure --prefix=$HOME/src/celt
    make
    make install
    done_wait
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
