require 'command'

store_filename = File.join(Dir.home, '.ward')
exit(WardCommand.run(store_filename, ARGV))