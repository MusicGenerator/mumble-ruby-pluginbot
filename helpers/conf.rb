require 'yaml'
require 'cgi'

module Conf
  @@configuration = Hash.new

  def Conf.gvalue(key)
    hash = @@configuration.clone
    key.split(':').each do |keyv|
      begin
        hash = hash[keyv]
      rescue
        nil
      end
    end
    return hash
  end

  def Conf.nvalue(key, value)
    start = 0
    newhash = Hash.new
    key.split(':').reverse_each do |keyv|
      if start == 0
        newhash[keyv]=value
      else
        oldhash = newhash.clone
        newhash = Hash.new
        newhash[keyv]= oldhash.clone
      end
      start += 1
    end
    return newhash
  end

  def Conf.svalue(key, value)
    #deep_merge!(@@configuration, nvalue(key, value))
    merger = proc{|key, v1, v2|
      !(Hash === v1) && !(Hash === v2) ? v1 = v2 : v1 = v1
      Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    @@configuration.merge! nvalue(key,value), &merger
  end

  def Conf.load(file)
    #deep_merge!(@@configuration, YAML::load_file(file))
    merger = proc{|key, v1, v2|
      !(Hash === v1) && !(Hash === v2) ? v1 = v2 : v1 = v1
      Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    @@configuration.merge! YAML::load_file(file), &merger
  end

  def Conf.overwrite(hash)
    @@Configuration = Hash.new
    @@Configuration = hash.clone
  end

  def Conf.get
    @@configuration
  end


end
