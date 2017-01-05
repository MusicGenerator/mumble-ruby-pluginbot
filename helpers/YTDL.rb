#!/usr/bin/env ruby


#
# Simple Class that capsule youtube-dl

require 'cgi'

class YTDL
  # CONSTANTS

  def initialize
    @filetypes= ["ogg", "mp3", "mp2", "m4a", "aac", "wav", "ape", "flac", "opus"].freeze
    @list = ""
    @presixes = ""
    @exe = ""
    @option = ""
    @temp = ""
    @dest = ""
    @filelist = ""
    @song = Queue.new
    @suffix = Queue.new
  end

  def prefix(prefixes)
    @prefixes = prefixes
  end

  def executeable(executeable)
    @exe = executeable
  end

  def options(options)
    @options = options
  end

  def temp(path)
    @temp=path
  end

  def dest(path)
    @dest=path
  end

  def size
    @suffix.size == @song.size ? @song.size : -1
  end

  def get_song
    if @song.size > 0
      answer = Hash.new
      answer[:name] = @song.pop
      answer[:extention] = @suffix.pop
      answer
    else
      nil
    end
  end

  def get_files(site)

    # If filelist is not empty dont start a new download.
    # wait until it is empty
    while @filelist != ""
      sleep 1
    end
    if @exe != ""
      `#{@prefixes} #{@exe} #{@options} --write-thumbnail -x --audio-format best -o '#{@temp}%(title)s.%(ext)s' '#{site}'`
      @filelist = `#{@prefixes} #{@exe} --get-filename #{@options} -i -o '#{@temp}%(title)s' '#{site}'`
    end

    # If there are songs in queue don't start a new remux cycle.
    # wait until it is empty
    while @song.size != 0
      sleep 1
    end
    @filelist.split("\n").each do |file|
      file.slice! @temp
      @filetypes.each do |ending|
        if File.exist?("#{@temp}#{file}.#{ending}")
          system ("#{@prefixes} convert '#{@temp}#{file}.jpg' -resize 320x240 '#{@dest}#{file}.jpg' ")
          if Conf.gvalue("plugin:youtube:to_mp3").nil?
            # Mixin tags without recode on standard
            system ("#{@prefixes} ffmpeg -i '#{@temp}#{file}.#{ending}' -acodec copy -metadata title='#{file}' '#{@dest}#{file}.#{ending}'") if !File.exist?("#{@dest}#{file}.#{ending}")
            if File.exist?("#{@dest}#{file}.#{ending}")
              @song << file
              @suffix << ".#{ending}"
            end
          else
            # Mixin tags and recode it to mp3 (vbr 190kBit)
            system ("#{@prefixes} ffmpeg -i '#{@temp}#{file}.#{ending}' -codec:a libmp3lame -qscale:a 2 -metadata title='#{file}' '#{@dest}#{file}.mp3'") if !File.exist?("#{@dest}#{file}.mp3")
            if File.exist?("#{@dest}#{file}.mp3")
              @song << file
              @suffix << ".mp3"
            end
          end
        end
      end
    end
    # download process is done, clear list to indicate other threads this.
    @filelist = ""
  end

end
