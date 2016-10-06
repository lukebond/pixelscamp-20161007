%title: Pixels Camp 2016 - Deploying Node.js Apps with systemd
%author: @lukeb0nd
%date: 2016-10-07

-> ## Running <-

\                                     \_   \_           \_        \_     
                                    | \\ | |         | |      (_)    
                                    |  \\| | \___   \__| | \___   \_ \___ 
                                    | . \` |/ \_ \\ / \_` |/ \_ \\ | / \__|
                                    | |\\  | (\_) | (\_| |  \__/\_| \\\__ \\
                                    |\_| \\\_|\\\___/ \\\__,\_|\\\___(\_) |\___/
                                                            \_/ |    
                                                           |\__/     
-> ## in Production with <-
\                                               \_                     \_ 
                                 \___ \_   \_ \___| |\_ \___ \_ \__ \___   \__| |
                                / \__| | | / \__| \__/ \_ \\ '\_ \` \_ \\ / \_\` |
                                \\\__ \\ |\_| \\\__ \\ ||  \__/ | | | | | (\_| |
                                |\___/\\\__, |\___/\\\__\\\___|\_| |\_| |\_|\\\__,\_|
                                     |\___/                             


-> # Pixels Camp <-
-> ## October 7th 2016 <-

-> Luke Bond <-
-> @lukeb0nd <-

---

# WHO AM I?

- I'm a backend developer turned DevOps practitioner
- Recently I've mostly done Node.js and Docker
- Built an OS project called "Paz" - _http://paz.sh_

---

# WHAT'S THIS TALK ABOUT?

This talk in a nutshell:

-> *Use your Linux init system to run your Node.js apps* <-
-> *It's easy, powerful and the tooling is great!* <-
^

- Most of this isn't Node specific
^
- I'll talk about PM2 as a reference case
^
- Then I'll show you hands-on how to achieve the same things with systemd
^
- This talk will be mostly demo
^
- I will move quite quickly (sorry) but the final result will be available to copy-paste!




-> ## All unit files in this talk can be found here, along with the slides: <-

-> _https://github.com/lukebond/pixelscamp-20161007 <-

---

# PROCESS MONITORS

There are various popular process monitors in use today, depend on your language/runtime:

- mon, nodemon, monit, forever
- PM2
- unicorn, gunicorn
- daemontools
- runit
- supervisord

---

# PM2

- I'll be referring a lot to PM2 because mostly I speak to the Node community,
  wherein it is well known
- Many of you may use PM2 in production; or another process monitor like those
  listed above
- _Please note_ that I have nothing against PM2 or any of these tools!
^

Why is PM2 (and other process monitors) so popular? Because it makes the
following very easy:
^

1. Process management
^
2. Log management
^
3. Magic/seamless sharing of ports
^
4. Maybe you don't have root access to your servers!
^

PM2 has great UX too. It's a powerful tool.

---

# LEARN TO LINUX

Why bother learning Linux instead of sticking to PM2 or similar?

- You can learn to do all these things yourself, using basic Linux tooling
^
- It's easy and it's fun
^
- Broaden your skill-set!
^
- Impress your friends!
^
- Learn that you don't need a process monitor
^
- Deploy applications that any Linux sysadmin outside the Node.js world will understand
^
- systemd is now more or less the standard init system
^

*My goal here is to dispel myths around the complexity of these things.*

---

# LINUX INIT SYSTEMS

- Linux has something called an "init system" that runs as PID1
^
- It's the ancestor of all processes on Linux; the ultimate process monitor!
^
- Each service gets an init script for start|stop|restart etc.
  - e.g. Databases, web servers, etc.
^
- Basically what PM2 does, but OS-wide
^
- Linux has been doing this for years
^
- Most modern distros use systemd as the init system

---

# SYSTEMD BASICS

- We tell systemd about the services we want it to run by writing unit files
^
- A unit file is a text file; like an INI file
^
- They go in `/etc/systemd/system`
^
- When we change those files on disk (e.g. add a new unit), we signal
  systemd to reload its config by issuing the command `systemctl daemon-reload`

---

# SAMPLE APP

- I've built a contrived sample app in Node.js that talks to Redis:

-> _https://github.com/lukebond/demo-api-redis_ <-
^

- It's basically HTTP Hello World with a Redis counter
^
- In this talk I'll set it all up with systemd
^
- You will need:
  - A version of Linux with systemd \*
  - Node installed
  - Redis installed
^
- This would be better with containers; hopefully I'll have time to get into that





\* These distros: _https://en.wikipedia.org/wiki/Systemd#Adoption_and_reception_

---

# MY FIRST UNIT FILE

Let's write our first unit file for our Node.js sample app:
^

    # /etc/systemd/system/demo-api-redis@.service
    [Unit]
    Description=HTTP Hello World
    After=network.target
    
    [Service]
    User=luke
    Environment=REDIS_HOST=localhost
    WorkingDirectory=/home/luke/Development/demo-api-redis
    ExecStart=/usr/bin/node index.js
    
    [Install]
    WantedBy=multi-user.target
^

Create this file and copy it into the above directory
^

*Don't forget to change username and paths where appropriate (containers help with this! Later...)*

---

# MY FIRST UNIT FILE

- Signal systemd to reload the config
^
- Enable and start the service \*
^

    $ systemctl daemon-reload
    $ systemctl enable demo-api-redis@1
    $ systemctl start demo-api-redis@1
^

- Of course it fails because Redis isn't running!
^
- Let's explore dependencies with systemd...



\* Learn more about `systemctl` here:

[systemctl tutorial on Digital Ocean](https://goo.gl/LxsaOf)

---

# SYSTEMD DEPENDENCIES - Wants=

- Use `Wants=` in `[Unit]` section of unit files to declare dependencies
^
- Starting this unit will trigger wanted units to be started also
^

    # /etc/systemd/system/demo-api-redis@.service
    [Unit]
    Description=HTTP Hello World
    After=network.target
    Wants=redis.service
    
    [Service]
    User=luke
    Environment=REDIS_HOST=localhost
    WorkingDirectory=/home/luke/Development/demo-api-redis
    ExecStart=/usr/bin/node index.js
    
    [Install]
    WantedBy=multi-user.target

    $ systemctl daemon-reload
    $ systemctl restart demo-api-redis@1
^

- Note that now Redis gets started too!

---

# HANDLING CRASHES, RESTARTS, ETC. (1/3)

- Let's kill the node process and see what happens:
^

    $ kill -9 $(pgrep "node index.js")
    $ systemctl status demo-api-redis@1 | grep Active
    Active: failed (Result: signal) since Thu 2016-06-02 11:50:32 BST; 47s ago
^

- The process hasn't been automatically restarted after the "crash"
^
- Add the following to the `[Service]` section of the unit file to fix this:
^

    Restart=always
    RestartSec=500ms
    StartLimitInterval=0
^

- This example will restart the service indefinitely with 500ms delay
^
- There is great flexibility in how this can be configured!
^
- The above should be fine though

---

# HANDLING CRASHES, RESTARTS, ETC. (1/3)

    $ kill -9 $(pgrep "node index.js")
    $ systemctl status demo-api-redis@1 | grep Active
    Active: active (running) since Thu 2016-06-02 12:12:05 BST; 22s ago
^

- It has been restarted!
^
- What about reboots? systemd will start units on boot that are _enabled_

    $ systemctl status demo-api-redis@1 | grep Loaded
^

- I'm going to risk a reboot; cross your fingers for me & pray to the `xrandr` gods!

---

# LOGS (2/3)

- systemd has a powerful tool for working with logs for all services: `journalctl`
^
- To scroll through logs for a unit or service:

    $ journalctl -u demo-api-redis@1
^

- To follow said logs:

    $ journalctl -u demo-api-redis@1 -f

---

# LOGS (2/3)

- You can ask for logs since the last boot:

    $ journalctl -u demo-api-redis@1 --boot
^

- You can ask for logs since a certain time; e.g.:

    $ journalctl -u demo-api-redis@1 --since 08:00
    $ journalctl -u demo-api-redis@1 --since today
    $ journalctl -u demo-api-redis@1 --since yesterday
    $ journalctl -u demo-api-redis@1 --since 2016-06-02 15:36:00

---

# LOGS (2/3)

- You can filter by log level (console.log, console.error, etc.):

    $ journalctl -u demo-api-redis@1 -p err
^

- There is so much more you can do; it's _super_ powerful. Great docs here:

  [journalctl tutorial on Digital Ocean](https://goo.gl/T3gr5b)

---

# MULTIPLE INSTANCES

- We should run as many Node.js processes as we have cores
^
- Assuming we have four cores, let's run three Node.js instances, leaving one for Redis
^
- First, let's modify the unit file to set different ports for them
^

    # /etc/systemd/system/demo-api-redis@.service
    [Unit]
    Description=HTTP Hello World
    After=network.target
    Requires=redis.service
    
    [Service]
    Environment=REDIS_HOST=localhost
    Environment=LISTEN_PORT=900%i
    WorkingDirectory=/home/luke/Development/demo-api-redis
    ExecStart=/usr/bin/node index.js
    Restart=always
    RestartSec=500ms
    StartLimitInterval=0
    
    [Install]
    WantedBy=multi-user.target

---

# MULTIPLE INSTANCES

- And now reload the unit and start and enable the other instances:
^

    $ systemctl daemon-reload
    $ systemctl enable demo-api-redis@{2,3}
    $ systemctl start demo-api-redis@{2,3}
    $ systemctl restart demo-api-redis@1
    $ netstat -tlpn | grep 900
    tcp6     0     0 :::9001      :::*       LISTEN      2654/node           
    tcp6     0     0 :::9002      :::*       LISTEN      2656/node           
    tcp6     0     0 :::9003      :::*       LISTEN      2704/node           
^

- Cool! There is one final feature: a local load balancing proxy...

---

# SIMPLE LOAD BALANCING WITH balance (3/3)

- `balance` is a simple, light-weight load balancer

  _https://www.inlab.de/balance.html_
^

- I've installed it locally
- We can set it up with a one-liner:

    $ balance -f 9000 127.0.0.1:900{1,2,3}
    $ curl localhost:9000
    "Hello, world 192.168.1.39! 20 hits."

---

# SIMPLE LOAD BALANCING WITH balance

- But let's do this the systemd way, with the following unit file:
^

    # /etc/systemd/system/balance.service
    [Unit]
    Description=Balance - Simple TCP Load Balancer
    After=syslog.target network.target nss-lookup.target
    
    [Service]
    ExecStart=/usr/bin/balance -f 9000 127.0.0.1:9001 127.0.0.1:9002 127.0.0.1:9003
    
    [Install]
    WantedBy=multi-user.target

---

# SIMPLE LOAD BALANCING WITH balance

- As usual, signal systemd to reload and then enable and start the service

    $ systemctl daemon-reload
    $ systemctl enable balance
    $ systemctl start balance
^

- Does it work?
^

    $ curl localhost:9000
    "Hello, world 172.20.10.2! 29 hits."

---

# WHERE TO FROM HERE?

- This is just the basics of systemd
^
- It should be easy to build something dynamic on top of this
  - As opposed to hardcoded ports in `balance.service`
^
- SSL termation, hooking up to external load balancers, etc. I'll leave to you
^
- Containers!
^
  - Normally I'd do all this with containers
^
    - Using *rkt* or *runc* because Docker & systemd sometimes don't play nicely together
^
  - I left it out today to reduce the number of new things introduced
^
  - Talk to me about containers, Node.js & systemd if you're interested!

---

# BONUS MATERIAL: CONTAINERISATION!

- We can make some simple modifications to our unit files to run them with Docker
^
- Firstly, add the following lines to the `[Unit]` section of your unit files:

    [Unit]
    After=docker.server
    Requires=docker.server
^

- This will ensure the units are started after Docker
^
  - No need for `network.target` anymore

---

# UNIT FILE CHANGES FOR CONTAINERISATION

- We'll also replace our `ExecStart` line with the following:
^

    ExecStartPre=-/usr/bin/docker stop %n
    ExecStartPre=-/usr/bin/docker rm %n
    ExecStartPre=/usr/bin/docker pull lukebond/demo-api-redis
    ExecStart=/usr/bin/docker run --rm --name %n lukebond/demo-api-redis
^

- The `stop|rm|pull` lines are important to ensure there are no name clashes
^
- The `-` symbol in the first two `ExecStartPre` lines means "don't fail on non-zero exit code"
^
- We have to pass environment variables to Docker, e.g.:
^

    Environment=REDIS_HOST=redis
    Environment=LISTEN_PORT=900%i
    ...
    ExecStart=/usr/bin/docker run --rm --env REDIS_HOST --env LISTEN_PORT --name %n redis
^

- Note that I've changed the Redis host environment variable; `localhost`
  won't work in a container
^
- Note `--net=host` for the balance unit file- so it can access `localhost:900*`

---

# FINAL UNIT FILES - NODE APP

    # /etc/systemd/system/demo-api-redis.service
    [Unit]
    Description=HTTP Hello World
    After=docker.service
    Requires=docker.server
    Wants=docker.redis.service
    
    [Service]
    Environment=REDIS_HOST=redis
    Environment=LISTEN_PORT=900%i
    User=luke
    ExecStartPre=-/usr/bin/docker stop %p-%i
    ExecStartPre=-/usr/bin/docker rm %p-%i
    ExecStartPre=-/usr/bin/docker pull lukebond/demo-api-redis
    ExecStart=/usr/bin/docker run --rm --env REDIS_HOST --env LISTEN_PORT --name %p-%i -p 900%i:900%i --link docker.redis.service:redis lukebond/demo-api-r
    Restart=always
    RestartSec=500ms
    StartLimitInterval=0
    
    [Install]
    WantedBy=multi-user.target

---

# FINAL UNIT FILES - REDIS

    # /etc/systemd/system/docker.redis.service
    [Unit]
    Description=Redis Container
    After=docker.service
    Requires=docker.service
    
    [Service]
    User=luke
    ExecStartPre=-/usr/bin/docker stop %n
    ExecStartPre=-/usr/bin/docker rm %n
    ExecStartPre=-/usr/bin/docker pull redis
    ExecStart=/usr/bin/docker run --rm --name %n redis
    TimeoutStartSec=0
    Restart=always
    
    [Install]
    WantedBy=multi-user.target

---

# FINAL UNIT FILES - BALANCE

    # /etc/systemd/system/docker.balance.service
    [Unit]
    Description=Balance - Simple TCP Load Balancer
    After=docker.service
    Requires=docker.service
    
    [Service]
    User=luke
    ExecStartPre=-/usr/bin/docker stop %n
    ExecStartPre=-/usr/bin/docker rm %n
    ExecStartPre=-/usr/bin/docker pull lukebond/docker-balance
    ExecStart=/usr/bin/docker run --name %n --net=host -p 9000:9000 lukebond/docker-balance -f 9000 127.0.0.1:9001 127.0.0.1:9002 127.0.0.1:9003
    TimeoutStartSec=0
    Restart=always
    
    [Install]
    WantedBy=multi-user.target

---

# CONCLUSION

- Learn to use systemd for your Linux production machines
^
- Use my unit files as a starting point
^
- systemd has a learning curve but it isn't difficult
^
- The tools are mature and powerful
^
- You'll realise that you don't need a process monitor
^
  - What starts your process monitor, after all?
^

## LINKS

- Repository with slides, unit files etc. here:

-> _https://github.com/lukebond/pixelscamp-20161007 <-

---

## FURTHER READING

- [systemd distros](https://en.wikipedia.org/wiki/Systemd#Adoption_and_reception)
- [Good article on using systemctl](https://goo.gl/LxsaOf)
- [Good article on using journalctl](https://goo.gl/T3gr5b)
- [The creator of systemd talking about security features](https://www.youtube.com/watch?v=hiW8eIdcRgo&list=PLlh6TqkU8kg_3FpXLlHMnoVqKZysIzXlK&index=6)
- [Videos from systemd conf 2015](https://www.youtube.com/channel/UCvq_RgZp3kljp9X8Io9Z1DA)
- [systemd unit file man page](https://www.freedesktop.org/software/systemd/man/systemd.unit.html)
- [systemd service file man page](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [Slides presented with *mdp*](https://github.com/visit1985/mdp)

---



-> # THANKS! <-



-> Thanks for listening! Go and read the repo and play. <-

-> Any questions, contact me: <-


-> ## @lukeb0nd <-
-> ## luke.n.bond@gmail.com <-


-> Or come and say "hi" during Pixels Camp! <-
