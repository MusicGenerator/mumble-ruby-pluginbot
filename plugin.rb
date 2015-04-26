class Plugin
  def self.plugins
    @plugins ||= []
  end
  
  def self.inherited(klass)
    @plugins ||= []
    
    @plugins << klass
  end
  
  # Usually a good idea for debugging if you have lots of methods
  def handle_chat(msg, message)
    #raise "#{self.class.name} doesn't implement `handle_chat`!"
  end
  
  def handle_command(command)
    #raise "#{self.class.name} doesn't implement `handle_command`!"
  end
  
  def handle_response
    #
  end
  
  def handle_help(text)
    text << "#{self.class.name} does'nt implement a help"
  end
  
  def init(init)
  end
end
 

 
#Plugin.plugins.each do |plugin_class|
#  plugin_class.new.handle_command('test')
#end