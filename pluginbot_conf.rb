def ext_config()
	puts "Config loaded!"

    
    #This template must always contain four %s strings.
	@template_if_comment_enabled = "<b>Artist: </b>%s<br />"\
					+ "<b>Title: </b>%s<br />" \
					+ "<b>Album: </b>%s<br /><br />" \
					+ "<b>Write %shelp to me, to get a list of my commands!"
	
	#This template must always contain one %s string.
	@template_if_comment_disabled = "<b>Artist: </b>DISABLED<br />"\
					+ "<b>Title: </b>DISABLED<br />" \
					+ "<b>Album: </b>DISABLED<br /><br />" \
					+ "<b>Write %shelp to me, to get a list of my commands!"
    
    
    # ------------------------------------------------------------------------------------------------------------------------------------------- #
    # superbot.rb configuration                                                                                                                   #
    # ------------------------------------------------------------------------------------------------------------------------------------------- #
    # (will not be needed and used with superbot_2.rb, still leaving here because compatibility)                                                  #
    # You should delete this section or comment it out so you can not be confused longer because of duplicate settings when you use superbot_2.rb #
    # ------------------------------------------------------------------------------------------------------------------------------------------- #
    
	@controlstring = "." 				#Change it if you want to use another starting string/symbol for the commands.
	@debug = true					#Whether debug mode is on or off.
	@use_vbr = 1 					#Default for mumble-ruby is 0 in order to use cbr, set to 1 to use vbr.
	@listen_to_private_message_only = true 		#Wheter the bot should only listen to private messages.
	@listen_to_registered_users_only = true 	#Whether the bot should only react to commands from registered users.
	@stop_on_unregistered_users = true 	        #Whether the bot should stop playing music if a unregistered user joins the channel.
	@use_comment_for_status_display = false 	#Whether to use comment to display song info; false = send to channel, true = comment.

    # End of superbot.rb configuation------------------------------------------------------------------------------------------------------------ #

    # ------------------------------------------------------------------------------------------------------------------------------------------- #
    # superbot_2.rb configuration                                                                                                                 #
    # ------------------------------------------------------------------------------------------------------------------------------------------- #
    # (will not be needed and used with superbot.rb.                                                                                              #
    # You should delete this section or comment it out so you can not be confused longer because of duplicate settings when you use superbot.rb   #
    # ------------------------------------------------------------------------------------------------------------------------------------------- #
	
    @settings = {   version: 2.0, 
                    # if ducking true bot will lower volume when other's speak
                    ducking: false, 
                    # see superbot_2.rb about chan_notify variable
                    chan_notify: 0x0000, 
                    controlstring: ".", 
                    # if you want some debug info on terminal
                    debug: false, 
                    listen_to_private_messsage_only: true, 
                    listen_to_registert_users_only: true, 
                    # set to 0 if you want a constant bitrate setting
                    use_vbr: 1, 
                    # set bitrate to bitspersecond (bps) [not kbit!]
                    quality_bitrate: 72000,
                    # bot will stop when a unregisterd user join channel if set to true
                    stop_on_unregistered_users: true,
                    # use mumble comment for status display (need a patched mumble-ruby) - see for dafoxia in github
                    use_comment_for_status_display: true,
                    # comment_aviable will be overwritten by bot if capability for comments is in mumble-ruby
                    set_comment_available: false,
                    # begin mumble server config
                    mumbleserver_host: "your.hoster.name",
                    mumbleserver_port: 64738,
                    mumbleserver_username: "Musikbot",
                    mumbleserver_userpassword: "",
                    mumbleserver_targetchannel: "channel bot will join at start",
                    # begin mpd config
                    mpd_fifopath: "/path/to/fifo.file",
                    mpd_host: "localhost",
                    mpd_port: 7701,
                    # controllable should set to true else bot can't controlled by mumble-chat
                    controllable: true,
                    # path where certificates are stored
                    certdirectory: "/home/botmaster/certs",
                    # bot need binding for super user command?
                    need_binding: false,
                    # leave it to nobody else binding will fail (internal variable at this time)
                    boundto: "nobody"
                    
    }

	@superanswer = "<img src='data:image/png;base64,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'/>"
    @superpassword = "kaguBe gave me all the power from kaguBe and I wish to "                     
    
    # End of superbot.rb configuation------------------------------------------------------------------------------------------------------------ #
   
end
