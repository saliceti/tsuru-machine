# Install Tsuru server

## Official release
```
$ make
```

## Development
* Clone Tsuru dockerized setup from https://github.com/tsuru/dockerized-setup.git
* Tweak Dockerfiles as required
* Run:

```
$ make dev DOCKERIZED_SETUP_DIR=<directory path>
```

# Install client

## Configure tsuru client

```
$ docker-machine ip docker-tsuru-admin
192.168.99.100
$ tsuru target-add -s machine http://192.168.99.100:8000
New target machine -> http://192.168.99.100:8000 added to target list and defined as the current target
```


## Create admin user

```
$ tsuru user-create clark@dailyplanet.com
Password: 
Confirm: 
User "clark@dailyplanet.com" successfully created!
```

## Login

```
$ tsuru login clark@dailyplanet.com
Password: 
Successfully logged in!
```

## Create admin team

```
$ tsuru team-create admin
Team "admin" successfully created!
```

## Create pool

```
$ tsuru-admin pool-add default
$ tsuru-admin pool-teams-add default admin
```

## Register nodes

```
$ tsuru-admin docker-node-add --register address=http://192.168.99.101:2375 pool=default
Node successfully registered.

$ tsuru-admin docker-node-list
+----------------------------+---------+---------+--------------+
| Address                    | IaaS ID | Status  | Metadata     |
+----------------------------+---------+---------+--------------+
| http://192.168.99.102:2375 |         | pending | pool=default |
+----------------------------+---------+---------+--------------+
```
After a few minutes:

```
$ tsuru-admin docker-node-list
+----------------------------+---------+--------+----------------------------------+
| Address                    | IaaS ID | Status | Metadata                         |
+----------------------------+---------+--------+----------------------------------+
| http://192.168.99.102:2375 |         | ready  | LastSuccess=2015-10-20T22:54:01Z |
|                            |         |        | pool=default                     |
+----------------------------+---------+--------+----------------------------------+
```


## Install platform

```
$ tsuru-admin platform-add python --dockerfile https://raw.githubusercontent.com/tsuru/basebuilder/master/python/Dockerfile
Step 0 : FROM ubuntu:14.04
[...]
OK!
Platform successfully added!
```

## Add public key

```
$ tsuru key-add mykey  ~/.ssh/id_rsa.pub 
```

## Git clone
```
$ git clone https://github.com/tsuru/tsuru-dashboard.git
```

## Create app

```
$ tsuru app-create dashboard python
App "dashboard" has been created!
Use app-info to check the status of the app and its units.
Your repository for "dashboard" project is "ssh://git@gandalf.service.consul/dashboard.git"
```

## Deploy app

```
$ git push ssh://git@gandalf.service.consul/dashboard.git master
```
