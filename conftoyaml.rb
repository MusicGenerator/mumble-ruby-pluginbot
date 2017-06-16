#!/usr/bin/env ruby

require "yaml"
require_relative 'pluginbot_conf.rb'


def read_newconfig

end

def read_old_config
  @settings = Hash.new()
  begin
    require_relative 'pluginbot_conf.rb'
    std_config()
  rescue
    puts "Config could not be loaded! YAML Config will be emty!"
  end
  return @settings
end

def write_config
  begin
    File.open(@openfile, 'w') {|f| f.write @config.to_yaml }
    puts "Configuration #{@openfile} written."
  rescue
    puts "File '#{@openfile}' could not be written!'"
  end
end

def read_config(configfile)
  begin
    @config = YAML::load_file(configfile)
    @openfile = configfile
  rescue
    puts "File #{configfile} could not be read"
  end
end


c = read_old_config

read_config("config/config.yml")
@config[:debug] = c[:debug].to_s
@config["main"]["tempdir"] = c[:main_tempdir].to_s
@config["main"]["ducking"] = c[:ducking]
@config["main"]["stop_on_unregistered"] = c[:stop_on_unregistered_users]
@config["main"]["control"]["string"] = c[:controlstring]
@config["main"]["certfolder"] = c[:certdirectory]
@config["main"]["fifo"] = c[:mpd_fifopath]
@config["main"]["logo"] = c[:logo]
@config["mumble"]["use_vbr"] = c[:use_vbr]
@config["mumble"]["host"] = c[:mumbleserver_host]
@config["mumble"]["port"] = c[:mumbleserver_port]
@config["mumble"]["name"] = c[:mumbleserver_username]
@config["mumble"]["password"] = c[:mumbleserver_password]
@config["mumble"]["channel"] = c[:mumbleserver_targetchannel]
@config["main"]["control"]["historysize"] = c[:control_historysize]
write_config

read_config("plugins/bandcamp.yml")
@config["plugin"]["bandcamp"]["folder"]["download"] = c[:bandcamp_downloadsubdir]
@config["plugin"]["bandcamp"]["folder"]["temp"] = c[:bandcamp_tempsubdir]
@config["plugin"]["bandcamp"]["youtube_dl"]["path"] = c[:bandcamp_youtubedl]
@config["plugin"]["bandcamp"]["to_mp3"] = c[:bandcamp_to_mp3]
write_config

read_config("plugins/soundcloud.yml")
@config["plugin"]["soundcloud"]["folder"]["download"] = c[:soundcloud_downloadsubdir]
@config["plugin"]["soundcloud"]["folder"]["temp"] = c[:soundcloud_tempsubdir]
@config["plugin"]["soundcloud"]["youtube_dl"]["path"] = c[:soundcloud_youtubedl]
@config["plugin"]["soundcloud"]["to_mp3"] = c[:soundcloud_to_mp3]
write_config

read_config("plugins/ektoplazm.yml")
@config["plugin"]["ektoplazm"]["folder"]["download"] = c[:ektoplazm_downloadsubdir]
@config["plugin"]["ektoplazm"]["folder"]["temp"] = c[:ektoplazm_tempsubdir]
write_config

read_config("plugins/mpd.yml")
@config["plugin"]["mpd"]["host"] = c[:mpd_host]
@config["plugin"]["mpd"]["port"] = c[:mpd_port]
@config["plugin"]["mpd"]["volume"] = c[:initial_volume]
@config["plugin"]["mpd"]["musicfolder"] = c[:mpd_musicfolder]
@config["plugin"]["mpd"]["template"]["comment"]["disabled"] = c[:mpd_template_comment_disabled]
@config["plugin"]["mpd"]["template"]["comment"]["enabled"] = c[:mpd_template_comment_enabled]
write_config
