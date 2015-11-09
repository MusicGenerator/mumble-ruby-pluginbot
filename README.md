#mumble-ruby-pluginbot
mumble-ruby-pluginbot is a Mumble-Ruby based, extensible bot which can play audio, be fed by different sources, and much more :)

##Features
- Can stream audio fed by a MPD
- Supports client certificates and thus can be registered on a server
- No need for additional web interfaces to control the bot; everything can be done with text commands on your Mumble server
- Support for plugins
- Can download music from Youtube or a search on Youtube
- Supports both CELT and Opus codec for maximum compatibility even on old Mumble servers

##Example for the bot usage
Lets say you want to listen to music from mozart...

First lets search on youtube:
    .yts mozart

The bot responds with:
    0 Mozart for Baby (3 Hours) - ...
    1 The Best of Mozart | 3 HOURS Piano Sonatas ...
    2 Mozart for Studying and ...

Now you can either let the bot download all search results
    .yta all

or just one specific song
    .yta 2

In both cases the bot will inform you about the current download status:
    [21:59:22] ♫ Music Bot 1: do 1 time(s)...
    [21:59:22] ♫ Music Bot 1: fetch and convert

Followed by a database update:
    [21:59:48] ♫ Music Bot 1: Waiting for database update complete...

Now lets show the current music queue:
    .queue

The bot responds with:
    0 The Best of Mozart _ 3 HOURS Piano Sonatas ...

Now lets playl the file with:
    .play 0

Have fun :)

More examples can be found in the official documentation.

##Documentation
* General information about the bot can be found at http://wiki.natenom.com/w/Mumble-Ruby-Pluginbot
* A tutorial about the the installation of Mumble-Ruby-Pluginbot can be found at http://wiki.natenom.com/w/Installation_of_mumble-ruby-pluginbot.
* If the bot is already running on your Mumble server, write **.help** to him.

##Included plugins
See [here for the list of all plugins](http://wiki.natenom.com/w/Category:Plugins_for_Mumble-Ruby-Pluginbot) and also for the documentation of each plugin.

Each plugin has its own help implemented. To get it, write **.help pluginname** to the bot, for example **.help youtube**

##Fully set up Mumble-Ruby-Pluginbot as a Virtual Appliance VirtualBox
Instead of setting up the bot yourself you can download a fully set up Mumble-Ruby-Pluginbot as a virtual appliance for VirtualBox. All you need to do after importing it to VirtualBox is to change one configuration file and add your server address and bot name.

The howto can be [found here](http://wiki.natenom.com/w/VirtualBox_Appliance_for_Mumble-Ruby-Pluginbot)

##Pre configured system images
###Banana Pi
[Download the image](http://soa.chickenkiller.com/daten/dafoxia_BananaPiPluginbot.zip)

- root password: pi
- user name:  botmaster
- user password: botmaster

###Raspberry Pi2
[Download the image](http://soa.chickenkiller.com/daten/dafoxia_raspi2.pluginbot.zip)

- root password: raspberry
- user name:  botmaster
- user password: botmaster
