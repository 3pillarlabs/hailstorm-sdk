worker_processes 2 # this should be >= nr_cpus

install_path = '/usr/local/lib'
hailstorm_web_home = "#{install_path}/hailstorm-web"
working_directory hailstorm_web_home

pid "#{hailstorm_web_home}/tmp/pids/unicorn.pid"
stderr_path "#{hailstorm_web_home}/log/unicorn.log"
stdout_path "#{hailstorm_web_home}/log/unicorn.log"

listen "#{hailstorm_web_home}/tmp/sockets/.unicorn.sock", :backlog => 64

