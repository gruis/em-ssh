#!/usr/bin/env ruby
require File.expand_path("../arg-parser", __FILE__)

host, user = require_host_user

require 'em-ssh/shell'
EM.run do
  EM::Ssh::Shell.new(host, user, "") do |shell|
    shell.callback do
      shell.expect(Regexp.escape('~]$ '))
      $stderr.puts shell.expect(Regexp.escape('~]$ '),'uname -a')
      $stderr.puts shell.expect(Regexp.escape('~]$ '), '/sbin/ifconfig -a')
      EM.stop
    end
    shell.errback do |err|
      $stderr.puts "error: #{err} (#{err.class})"
      EM.stop
    end
  end
end

