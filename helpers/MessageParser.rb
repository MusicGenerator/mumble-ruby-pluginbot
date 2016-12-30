#!/usr/bin/env ruby

# A parser for messages sent by users in Mumble.
# The invoker(?) can specify what he expects...

# Examples:
# message = .yts my little pony
# message = .help

def containsArguments(message="", argcount=0)
  begin
    parsed = message.split()
    if (parsed.length + 1) == argcount
      return parsed
    end
  rescue
    return false
  end

def splitMessage(message="", basecommand="")
  # basecommand is for example help, ytlink or bla. We need that in order to check the message.
  argcount = 0



  return argcount,

end

def MessageParser(message="", expected_command="", expected_argcount_min=0, expected_argcount_max=1)
  # argcount = number how many arguments the invoker expects
  # .yts my little pony
  # argcount = 3

  expectation_matched = false


  if expected zutreffend return (true, parsed_message)
  else
    return false
  end

end
