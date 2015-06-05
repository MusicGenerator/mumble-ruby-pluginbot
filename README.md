#mumble-ruby-pluginbot
mumble-ruby-pluginbot is a Mumble-Ruby based, extensible bot which can play audio, be fed by different sources, and much more :)

##Features
- Can stream audio fed by a MPD
- Supports client certificates and thus can be registered on a server
- No need for additional web interfaces to control the bot; everything can be done with text commands on your Mumble server
- Support for plugins
- Can download music from Youtube or a search on Youtube
- Supports both CELT and Opus codec for maximum compatibility even on old Mumble servers

##Documentation
* General information about the bot can be found at http://wiki.natenom.com/w/Mumble-Ruby-Pluginbot
* A tutorial about the the installation of Mumble-Ruby-Pluginbot can be found at http://wiki.natenom.com/w/Installation_of_mumble-ruby-pluginbot.
* If the bot is already running on your Mumble server, write **.help** to him.

##Included plugins
- **mpd**: Control the MPD that feeds the bot
- **youtube**: Search, download and add music
- **radiostream**: Let the bot play an internet radio stream
- **control**: Control the bot's behaviour
- **messages**: Handle the bot's messages

Each plugin has its own help implemented. To get it, write **.help pluginname** to the bot, for example **.help youtube**

More documentation about the plugins can be found at http://wiki.natenom.com/w/Usage_of_the_plugins_for_Mumble-Ruby-Pluginbot.

##Pre configured system images
###Banana Pi
[Download the image](http://soa.chickenkiller.com/daten/dafoxia_BananaPiPluginbot.zip)

- root password: pi
- user name:  botmaster
- user password: botmaster

###Raspberry Pi2
[Download the image](http://soa.chickenkiller.com/daten/dafoxia_raspi2.pluginbot.zip)

- root password: pi
- user name:  botmaster
- user password: botmaster
