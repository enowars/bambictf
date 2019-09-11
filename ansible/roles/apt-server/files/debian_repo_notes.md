# Steps to reproduce setup

## Setup Debian VM

1. Check out this [repo](https://github.com/geerlingguy/packer-debian-9).
2. `vagrant init geerlingguy/debian9` in a new folder.
3. `vagrant up`
4. `ssh vagrant@127.0.0.1 -p 2222 -i .vagrant/machines/default/virtualbox/private_key`

## Setup aptly

1. Check out this [repo](https://github.com/aptly-dev/aptly).
2. Append `deb http://repo.aptly.info/ squeeze main` to `/etc/apt/sources.list`
3. `sudo apt-key adv --keyserver pool.sks-keyservers.net --recv-keys ED75B5A4483DA07C`
4. `sudo apt-get update`
5. `sudo apt-get install aptly`

## Create and fill new local repo

* `aptly repo creat <name>` to create a new repo
* `aptly repo create <name> from snapshot <snapshot>` to start with saved snapshot
* `aptly repo add <reponame> <package file>|<directory>` (used `nodejs_10.15.2~dfsg-2_amd64.deb` for testing)
* `aptly publish repo -distribution="<codename>" <reponame>` to publish the repository directly. This is only used for the test scenario. Normaly a snapshot would be created first, which then can be published. `stretch` was used as distribution.
* `aptly serve` to serve the created release. After adding the server ip to the mirrorlist and remove the other mirrors the package could be loaded from the repo. Installation was unsucessfull, as necessary dependencies were not present. 


### Issues

There was a issue with adding packages to the local repo because of the GnuPG installation in the VM. Resolved it for the moment by setting the `gpgProvider` flag to `internal` within `~/.aptly.conf` for the moment.
[This](https://github.com/aptly-dev/aptly/issues/657) says there should be not problem. 
Also `gpgDisableSign` and `gpgDisableVerify` have been set to `true` as signing did not work automatically.

## Build and run docker container

1. Make sure docker is working on your host machine by runnung `docker info`
2. Build image from dockerfile: `docker build -t <imagename> .`
3. Interact with aptly by running: `docker run <imagename> <aptlycommand>`
4. (optional) Serve repository with aptly's built in webserver (Omit `-d` flag to check logs if sth is not working): 
`docker run -d -p 8080:8080 <imagename> api serve`

## Run nginx+aptly in container

sudo docker build -t aptly_test .
sudo docker run -d -p 8080:8080 aptly_test
sudo docker container ls -a 

### Handy commands

Drop all snapshots: `aptly snapshot list |  grep -oP "enowars-\d*" | xargs -I{} aptly snapshot drop {} `