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

  it "should raise a proper error with good backtrace on timeout" do
    EM.run {
      Fiber.new {
        timer = EM::Timer.new(4) { raise TimeoutError.new("failed to finish test") }
        EM::Ssh::Shell.new('icaleb.org', 'calebcrane', "") do |shell|
          shell.should be_a(EventMachine::Ssh::Shell)
          shell.wait_for(']$', :timeout => 1)
          e = shell.send_and_wait('uname -a', ']%', :timeout => 2) rescue $!
          e.should be_a(EM::Ssh::TimeoutError)
          e.backtrace.join.should include("#{__FILE__}:#{__LINE__ - 2}:in `block")
          timer.cancel
          EM.stop
        end
      }.resume
    }
  end # should raise a proper error with good backtrace on timeout

  specify "#wait_for should raise TimeoutError on timeout" do
    EM.run {
      Fiber.new {
        timer = EM::Timer.new(4) { raise TimeoutError.new("failed to finish test") }
        EM::Ssh::Shell.new('icaleb.org', 'calebcrane', "") do |shell|
          expect {
            shell.wait_for(']%', :timeout => 1)
          }.to raise_error(EM::Ssh::TimeoutError)
          timer.cancel
          EM.stop
        end
      }.resume
    }
  end
end # Ssh::Shell
