require 'em-ssh'
require_relative "spec_helper"


module EM::Ssh::Test
  include Constants

  describe "EM::Ssh" do
    it "should be addressable through EM::P and EM::Protocols" do
      EM::P.const_defined?(:Ssh).should be true
      EM::Protocols.const_defined?(:Ssh).should be true
      EM::P::Ssh.should == EM::Ssh
      EM::Protocols::Ssh.should == EM::Ssh
    end
    it "should raise a ConnectionTimeout error when a connection can't be established before the given timeout" do
      expect {
        EM.run {
          EM::Ssh.start(REMOTE1_IP, REMOTE1_USERNAME, :timeout => 1) do |ssh|
            ssh.callback { EM.stop }
            ssh.errback{|e| raise e }
          end
        }
      }.to raise_error(EM::Ssh::ConnectionTimeout)
    end # should raise a ConnectionTimeout error when a connection can't be established before the given timeout
    it "should raise a ConnectionError when the address is invalid" do
      expect {
        EM.run {
          EM::Ssh.start('0.0.0.1', 'caleb') do |ssh| # 0.0.0.1 is an invalid address
            ssh.callback { EM.stop }
            ssh.errback { |e| raise(e) }
          end
        }
      }.to raise_error(EM::Ssh::ConnectionFailed)
    end # should raise a ConnectionFailed when the address is invalid

    it "should run exec! succesfully" do
      res = ""
      EM.run {
        EM::Ssh.start(REMOTE2_URL, REMOTE2_USERNAME) do |con|
          con.errback do |err|
            raise err
          end
          con.callback do |ssh|
            res = ssh.exec!("uname -a")
            ssh.close
            EM.stop
          end
        end
      }
      res.should == REMOTE2_UNAME_A
    end
  end # EM::Ssh
end # module::EM::Ssh::Test
