require 'rake/testtask'
require 'fileutils'

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc 'Start irb tome session'
task :console do
  sh "irb -rubygems -I./lib -r ./lib/tome.rb"
end

desc 'Install tome gem'
task :install => :build do
  gemfile = Dir['gem/*.gem'][0]
  if !gemfile.nil?
    sh "gem install #{gemfile}"
  else
    puts 'Cound not find gem.'
  end
end

desc 'Uninstall tome gem'
task :uninstall do
  gemfile = Dir['gem/*.gem'][0]
  if !gemfile.nil?
    full_name = File.basename(gemfile, File.extname(gemfile))
    name = full_name[/.*(?=-)/]
    version = full_name[/(?<=-).*/]
    sh "gem uninstall #{name} --version #{version} -x"
  else
    puts 'Could not find gem.'
  end
end

desc 'Build tome gem'
task :build do
  FileUtils.mkdir_p('gem')
  sh 'gem build tome.gemspec'
  gemfile = Dir['*.gem'][0]
  FileUtils.mv gemfile, 'gem'
end

desc 'Run tests'
task :default => :test
