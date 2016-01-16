# Unicorn configuration file
#
# This is based on the default unicorn.rb shipped with Gitlab, but it has been
# modified to support the configuration shipped with the package. Feel free to
# modify it as necessary for your environment.
#

# WARNING: See /etc/gitlab/application.rb under "Relative url support" for the
# list of other files that need to be changed for relative url support.
#
# ENV['RAILS_RELATIVE_URL_ROOT'] = "/gitlab"

# Read about unicorn workers here:
# http://doc.gitlab.com/ee/install/requirements.html#unicorn-workers
#
worker_processes 3

# Help ensure your application will always spawn in the symlinked
# "current" directory that Capistrano sets up.
working_directory "/opt/gitlab-ce" # available in 0.94.0+

# Listen on both a Unix domain socket and a TCP port.
# If you are load-balancing multiple Unicorn masters, lower the backlog
# setting to e.g. 64 for faster failover.
listen "/var/run/gitlab-ce/gitlab-ce.socket", :backlog => 1024
listen "127.0.0.1:8080", :tcp_nopush => true

# nuke workers after 30 seconds instead of 60 seconds (the default)
#
# NOTICE: git push over http depends on this value.
# If you want be able to push huge amount of data to git repository over http
# you will have to increase this value too.
#
# Example of output if you try to push 1GB repo to GitLab over http.
#   -> git push http://gitlab.... master
#
#   error: RPC failed; result=18, HTTP code = 200
#   fatal: The remote end hung up unexpectedly
#   fatal: The remote end hung up unexpectedly
#
# For more information see http://stackoverflow.com/a/21682112/752049
#
timeout 60

# feel free to point this anywhere accessible on the filesystem
pid ENV["UNICORN_RAILS_PIDFILE"]

# By default, the Unicorn logger will write to stderr.
# Additionally, some applications/frameworks log to stderr or stdout,
# so prevent them from going to /dev/null when daemonized here:
stderr_path STDERR
stdout_path STDOUT

# combine Ruby 2.0.0dev or REE with "preload_app true" for memory savings
# http://rubyenterpriseedition.com/faq.html#adapt_apps_for_cow
preload_app true
GC.respond_to?(:copy_on_write_friendly=) and
  GC.copy_on_write_friendly = true

# Enable this flag to have unicorn test client connections by writing the
# beginning of the HTTP headers before calling the application.  This
# prevents calling the application for connections that have disconnected
# while queued.  This is only guaranteed to detect clients on the same
# host unicorn runs on, and unlikely to detect disconnects even on a
# fast LAN.
check_client_connection false

before_fork do |server, worker|
  # the following is highly recomended for Rails + "preload_app true"
  # as there's no need for the master process to hold a connection
  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.connection.disconnect!

  # The following is only recommended for memory/DB-constrained
  # installations.  It is not needed if your system can house
  # twice as many worker_processes as you have configured.
  #
  # This allows a new master process to incrementally
  # phase out the old master process with SIGTTOU to avoid a
  # thundering herd (especially in the "preload_app false" case)
  # when doing a transparent upgrade.  The last worker spawned
  # will then kill off the old master process with a SIGQUIT.
  old_pid = "#{server.config[:pid]}.oldbin"
  if old_pid != server.pid
    begin
      sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
      Process.kill(sig, File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end
  #
  # Throttle the master from forking too quickly by sleeping.  Due
  # to the implementation of standard Unix signal handlers, this
  # helps (but does not completely) prevent identical, repeated signals
  # from being lost when the receiving process is busy.
  # sleep 1
end

after_fork do |server, worker|
  # per-process listener ports for debugging/admin/migrations
  # addr = "127.0.0.1:#{9293 + worker.nr}"
  # server.listen(addr, :tries => -1, :delay => 5, :tcp_nopush => true)

  # the following is *required* for Rails + "preload_app true",
  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.establish_connection

  # if preload_app is true, then you may also want to check and
  # restart any other shared sockets/descriptors such as Memcached,
  # and Redis.  TokyoCabinet file handles are safe to reuse
  # between any number of forked children (assuming your kernel
  # correctly implements pread()/pwrite() system calls)
end
