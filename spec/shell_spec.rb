#!/usr/bin/env ruby
require 'bundler/setup'
require 'em-ssh/shell'
require 'rspec'

describe "Ssh::Shell" do
  it "should return a shell" do
    EM.run {
      Fiber.new {
        timer = EM::Timer.new(2) { raise "failed #{$0}" }
        shell = EM::Ssh::Shell.new('icaleb.org', 'calebcrane', "")
        shell.should be_a(EventMachine::Ssh::Shell)
        shell.wait_for(']$')
        shell.send_and_wait('uname -a', ']$').should include("GNU/Linux")
        timer.cancel
        EM.stop
      }.resume
    }  
  end # should return a shell
  
  it "should yield a shell" do
    EM.run {
      timer = EM::Timer.new(4) { raise "failed #{$0}" }
      EM::Ssh::Shell.new('icaleb.org', 'calebcrane', "") do |shell|
        shell.should be_a(EventMachine::Ssh::Shell)
        shell.wait_for(']$')
        shell.send_and_wait('uname -a', ']$').should include("GNU/Linux")
        shell.send_and_wait('/sbin/ifconfig -a', ']$').should include("eth0")
        timer.cancel
        EM.stop
      end
    }  
  end # should yield a shell

  it "should yield a shell even when in a fiber" do
    EM.run {
      Fiber.new{
        timer = EM::Timer.new(4) { raise "failed #{$0}" }
        EM::Ssh::Shell.new('icaleb.org', 'calebcrane', "") do |shell|
          shell.should be_a(EventMachine::Ssh::Shell)
          shell.wait_for(']$')
          shell.send_and_wait('uname -a', ']$').should include("GNU/Linux")
          timer.cancel
          EM.stop
        end
      }.resume
    }  
  end # should yield a shell
end # Ssh::Shell