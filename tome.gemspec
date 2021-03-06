require File.expand_path('lib/tome/version.rb', File.dirname(__FILE__))

Gem::Specification.new do |s|
  s.name = 'tome'
  s.version = Tome::VERSION
  s.executables << 'tome'
  s.date = Time.now.strftime('%Y-%m-%d')
  s.summary = 'Lightweight command-line password manager.'
  s.description = 'Lightweight password manager with a humane command-line interface. Manage your passwords with a single master password and strong encryption.'
  s.authors = ['Chris Schmich']
  s.email = 'schmch@gmail.com'
  s.files = Dir['{lib}/**/*.rb', 'bin/*', '*.md']
  s.require_path = 'lib'
  s.homepage = 'https://github.com/schmich/tome'
  s.license = 'MIT'
  s.required_ruby_version = '>= 1.9.3'
  s.add_runtime_dependency 'passgen', '~> 1.0'
  s.add_runtime_dependency 'clipboard', '~> 1.0'
  s.add_runtime_dependency 'ffi', '~> 1.1'
  s.add_development_dependency 'rake', '>= 0.9.2.2'
  s.post_install_message = <<END
-------------------------------
Run 'tome help' to get started.
-------------------------------
END
end
