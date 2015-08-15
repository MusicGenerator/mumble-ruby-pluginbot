def ext_config()
    puts "Own Config loading and overwriting default settings!"
    overwrite = {  
                    mumbleserver_host: "domain_or_ip_of_your_mumbleserver",
                    mumbleserver_port: 64738,
                    mumbleserver_username: "Name_of_your_bot",
                    mumbleserver_targetchannel: "Bottest",
                    mpd_fifopath: "/home/botmaster/mpd1/mpd.fifo",
                    mpd_port: 7701,
                 }
    @settings = @settings.merge(overwrite)
end
