require 'bundler/setup'
require 'rspec'
require_relative 'constants'

if ENV['VERBOSITY'] && Logger.const_defined?(ENV['VERBOSITY'])
  EM::Ssh.logger.level = Logger.const_get(ENV['VERBOSITY'])
end

RSpec.configure do |config|
  config.include EM::Ssh::Test
end
