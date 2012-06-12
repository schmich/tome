require 'rake/testtask'
require 'fileutils'

class GemInfo
  def initialize
    @gemspec_filename = Dir['*.gemspec'][0]
  end
   
  def spec
    @spec = @spec || eval(File.read(@gemspec_filename))
  end

  def name
    @name = @name || spec.name
  end

  def version
    @version = @version || spec.version.to_s
  end

  def gem_filename
    "#{name}-#{version}.gem"
  end

  def gemspec_filename
    @gemspec_filename
  end
end

$gem = GemInfo.new

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc "Start irb #{$gem.name} session"
task :console do
  sh "irb -rubygems -I./lib -r ./lib/#{$gem.name}.rb"
end

desc "Install #{$gem.name} gem"
task :install => :build do
  gemfile = "gem/#{$gem.gem_filename}"
  if !gemfile.nil?
    sh "gem install #{gemfile}"
  else
    puts 'Cound not find gem.'
  end
end

desc "Uninstall #{$gem.name} gem"
task :uninstall do
  sh "gem uninstall #{$gem.name} --version #{$gem.version} -x"
end

desc "Build #{$gem.name} gem"
task :build do
  FileUtils.mkdir_p('gem')
  sh "gem build #{$gem.gemspec_filename}"
  FileUtils.mv $gem.gem_filename, 'gem'
end

desc 'Run tests'
task :default => :test
