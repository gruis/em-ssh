require File.expand_path("../lib/em-ssh/version", __FILE__)
require "rubygems"
::Gem::Specification.new do |s|
  s.name                      = "em-ssh"
  s.version                   = EM::Ssh::VERSION
  s.platform                  = ::Gem::Platform::RUBY
  s.authors                   = ['Caleb Crane']
  s.email                     = ['em-ssh@simulacre.org']
  s.homepage                  = "http://github.com/simulacre/em-ssh"
  s.summary                   = 'An EventMachine compatible net-ssh'
  s.description               = ''
  s.required_rubygems_version = ">= 1.3.6"
  s.files                     = Dir["lib/**/*.rb", "bin/*", "*.md"]
  s.require_paths             = ['lib']
  s.executables               = Dir["bin/*"].map{|f| f.split("/")[-1] }
  s.license                   = 'MIT'

  # If you have C extensions, uncomment this line
  # s.extensions = "ext/extconf.rb"
  s.add_dependency 'eventmachine'
  s.add_dependency "net-ssh"
  # Not really necessary, but used in bin/em-ssh and bin/em-ssh-shell
  s.add_development_dependency 'ruby-termios'
  s.add_development_dependency "highline"
end
