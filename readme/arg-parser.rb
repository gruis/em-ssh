require "optparse"

def require_host_user
  summary =<<-SUMM
    A simple utility corresponding to a usage example in the
  [em-ssh](https://github.com/simulacre/em-ssh/) README. It requries a
  single argument user@host. You use must have an authorized ssh public
  key on the target host. After logging in a few non-destructive commands
  will be executed.
  SUMM

  host      = nil
  user      = nil
  user,host = ARGV[0].split("@") if ARGV[0]
  abort "Usage: #{File.basename($0)} user@host\n\n#{summary}" if ARGV.include?("-h") || host.nil? || user.nil?
  [host, user]
end
