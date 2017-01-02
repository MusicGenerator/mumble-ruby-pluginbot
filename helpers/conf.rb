require 'yaml'
require 'cgi'

module Conf
  @@configuration = Hash.new

  def Conf.gvalue(key)
    hash = @@configuration.clone
    key.split(':').each do |keyv|
      hash = hash[keyv]
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
    deep_merge!(@@configuration, nvalue(key, value))
  end

  def Conf.load(file)
    deep_merge!(@@configuration, YAML::load_file(file))
  end

  def Conf.get
    @@configuration
  end

  def Conf.html
    hash_to_table(@@configuration)
  end

  private

  def deep_merge!(target, data)
    merger = proc{|key, v1, v2|
      !(Hash === v1) && !(Hash === v2) ? v1 = v2 : v1 = v1
      Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    target.merge! data, &merger
  end

  def hash_to_table(hash)
    return CGI.escapeHTML(hash.to_s) if !hash.kind_of?(Hash)
    out = "<ul>"
    hash.each do |key, value|
      Symbol === key ? out << "<li><b>" : out << "<li>"
      out << "#{key}:" << "#{hash_to_table(value)}"
      Symbol === key ? out << "<\b><li>" : out << "<\li>"
    end
    out << "</ul>"
    return out
  end

end
