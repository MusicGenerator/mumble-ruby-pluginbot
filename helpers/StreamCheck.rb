#!/usr/bin/env ruby


#
# Simple Class to Check if a File is a mp3 or a ogg/opus type
# written espacially for check streaming url's
#

class StreamCheck
  MPEG2_5 = 0
  MPEG2   = 2
  MPEG1   = 3

  LAYERI    = 3
  LAYERII   = 2
  LAYERIII  = 1

  def initialize
    @samples_p_f = [0,0,0],[384,1152,1152],[384,1152,576],[384,1152,576]      # index 2 layer, index 1 mpeg-version
    @sampling_rate = [11025,12000,8000],[0,0,0],[22050,24000,16000],[44100,48000,32000] #index 1 mpeg-version, index 2 sampingrateindex
    @slot = [4,0,4,1]
    @bitrateMPEG1L1 =  [0, 32 , 64 , 96 , 128 , 160 , 192 , 224 , 256 , 288 , 320 , 352 , 384 , 416 , 448 , 0]
    @bitrateMPEG1L2 =  [0, 32 , 48 , 56 , 64 , 80 , 96 , 112 , 128 , 160 , 192 , 224 , 256 , 320 , 384 , 0]
    @bitrateMPEG1L3 =  [0, 32 , 40 , 48 , 56 , 64 , 80 , 96 , 112 , 128 , 160 , 192 , 224 , 256 , 320 , 0]
    @bitrateMPEG2L1 =  [0, 32 , 48 , 56 , 64 , 80 , 96 , 112 , 128 , 144 , 160 , 176 , 192 , 224 , 256 , 0]
    @bitrateMPEG2L2 =  [0, 8 , 16 , 24 , 32 , 40 , 48 , 56 , 64 , 80 , 96 , 112 , 128 , 144 , 160 , 0]
    @bitrateMPEG2L3 =  [0, 8 , 16 , 24 , 32 , 40 , 48 , 56 , 64 , 80 , 96 , 112 , 128 , 144 , 160 , 0]
    @channel_mode = ["stereo", "joint-stereo", "dual-channel", "mono"]
    @emphasis = ["none", "50/15 ms", "reserved", "CCIT J.17"]
  end

  def testurl(url)
    file = `curl -L --max-time 3 "#{url}" `
    opus  = checkopus(file)
    mp3   = checkmp3(file)
    return opus if opus[:verified]
    return mp3 if mp3[:verified]
  end

  def checkopus(file)
    bytefield = file.unpack('C*')
    info = Hash.new
    jump=0
    verified = 0
    (0..bytefield.size-40).each do |i|
      if bytefield[i].chr == "O" then
        opushead = ""
        (0..3).each do |j|
          opushead << bytefield[i+j].chr
        end
        if opushead == "OggS" then
          # possible a Ogg Header
          verified += 1 if i == jump
          info[:verified] = verified
          info[:structure_version] = bytefield[i+4].to_i
          header_type_flag = bytefield[i+5]
          info[:fresh_packet] = !((header_type_flag && 0x01)).zero?
          info[:first_page] = !((header_type_flag && 0x02) >> 2 ).zero?
          info[:last_page] = !((header_type_flag && 0x04) >>  4 ).zero?

          k = 0
          (13..5).each do |j|
            k = k * 256 + bytefield[i+j]
          end
          info[:absolute_granule_position]=k

          k = 0
          (17..14).each do |j|
            k = k * 256 + bytefield[i+j]
          end
          info[:stream_serial_number] = k

          k=0
          (21..18).each do |j|
            k = k * 256 + bytefield[i+j]
          end
          info[:page_sequence_no] = k

          k=0
          (22..25).each do |j|
            k = k * 256 + bytefield[i+j]
          end
          info[:page_checksum] = k.to_s(16)

          page_segments = bytefield[i+26]
          info[:page_segments] = page_segments

          jump = i + 27
          (26..page_segments+26).each do |j|
            key = "page_segment_" + (j-26).to_s
            k = bytefield[i+j]
            jump += k
            info[key.to_sym] = k
          end
        end
      end
    end
    return info
  end

  def checkmp3(file)
    bytefield = file.unpack('C*')
    lastbyte = Array.new(3,0)
    index = 0
    jump = 0
    verified = 0
    info = Hash.new
    bytefield.each do |byte|
      if index >= jump then

        dword = ('%32b' % (((lastbyte[2] * 256 + lastbyte[1]) * 256 + lastbyte[0]) * 256 + byte))

        lastbyte[2] = lastbyte[1]
        lastbyte[1] = lastbyte[0]
        lastbyte[0] = byte
        if dword[0..10] == "11111111111" then
          # Possible a mp3 header
          audio_version_id    = dword[11..12].to_i(2)
          layer_index         = dword[13..14].to_i(2)
          protection_bit      = dword[15].to_i(2)
          bitrate_index       = dword[16..19].to_i(2)
          sampling_rate_index = dword[20..21].to_i(2)
          padding_bit         = dword[22].to_i(2)
          private_bit         = dword[23].to_i(2)
          channel_mode        = dword[24..25].to_i(2)
          mode_extention      = dword[26..27].to_i(2)
          copyright_bit       = dword[28].to_i(2)
          original_bit        = dword[29].to_i(2)
          emphasis            = dword[30..31].to_i(2)

          if (index-4) == jump then
            verified += 1
            begin
              case audio_version_id
                when MPEG1
                  info[:mpeg]= "MPEG1"
                when MPEG2
                  info[:mpeg]= "MPEG2"
                when MPEG2_5
                  info[:mpeg]= "MPEG2.5"
                else
                  info[:mpeg]= "unknown"
              end
              info[:layer] = 4 - layer_index
              info[:protected] = protection_bit
              info[:private] = private_bit
              info[:copyright] = copyright_bit
              info[:original] = original_bit * 1000
              info[:bitrate] = bitrate(layer_index, audio_version_id, bitrate_index)
              info[:samplerate] = @sampling_rate[audio_version_id][sampling_rate_index]
              info[:emphasis] = @emphasis[emphasis]
              info[:channel_mode] =  @channel_mode[channel_mode]
              info[:mode_extention] = mode_extention
              info[:verified] = verified
            rescue
            end
          end

          begin
           framesize = (@samples_p_f[audio_version_id][layer_index]*1000 / 8 * bitrate(layer_index, audio_version_id, bitrate_index)) / @sampling_rate[audio_version_id][sampling_rate_index]
           framesize += @slot[audio_version_id] if padding_bit == 1
           jump = (index + framesize.to_i) - 4 # -4 because readahead
          rescue
          end
        end
      end
      index += 1

    end
    return info
  end

  private


  def bitrate(layer_index, audio_version_id, bitrate_index)
    if audio_version_id == MPEG1 then                               # MPEG Version 1
      to_return=@bitrateMPEG1L1[bitrate_index] if layer_index == 3  # Layer I
      to_return=@bitrateMPEG1L2[bitrate_index] if layer_index == 2  # Layer II
      to_return=@bitrateMPEG1L3[bitrate_index] if layer_index == 1  # Layer III
    else                                                            # MPEG Version 2 or 2.5
      to_return=@bitrateMPEG2L1[bitrate_index] if layer_index == 3  # Layer I
      to_return=@bitrateMPEG2L2[bitrate_index] if layer_index == 2  # Layer II
      to_return=@bitrateMPEG2L3[bitrate_index] if layer_index == 1  # Layer III
    end
    return to_return
  end
end
