require 'bundler/setup'
require 'rspec'
require_relative 'constants'

RSpec.configure do |config|
  config.include EM::Ssh::Test
end
