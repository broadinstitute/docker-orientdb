docker-orientdb
===============
[![](https://badge.imagelayers.io/broadinstitute/orientdb:2.1.0.svg)](https://imagelayers.io/?images=broadinstitute/orientdb:2.1.0 'Get your own badge on imagelayers.io')
[![Docker Hub](http://img.shields.io/badge/docker-hub-brightgreen.svg?style=flat)](https://registry.hub.docker.com/u/broadinstitute/orientdb/)

This repository is used to create an [OrientDB][1] [Docker][2] image.  This image is based on [Phusion Baseimage][3] to provide base OS and supervision support.

Running orientdb
----------------

The docker image contains a unconfigured orientdb installation and for running it you need to provide your own config folder from which [OrientDB][1] will read its startup settings.  To get an initial set of configurations from this setup, you can do something like the following:

```bash
# Run the container stock with no volumes mounted
docker run --name orientdb -d broadinstitute/orientdb:latest
# Go to the path that will eventually hold your configs
cd $CONFIG_PATH
# Copy the config directory from the stock container
docker cp orientdb:/opt/orientdb/config .
# Move all the files from that local "config" directory up a level
mv config/* .
# Remove the temporary "config" directory
rmdir config
```

The directory at **$CONFIG_PATH** should now have a copy of the stock config files that you can now edit to suit your own needs. To start [OrientDB][1] using volume mounts to keep your data safe outside the container, run:

```bash
docker run --name orientdb -d \
  -v $CONFIG_PATH:/opt/orientdb/config \
  -v $DATABASES_PATH:/opt/orientdb/databases \
  -v $BACKUP_PATH:/opt/orientdb/backup \
  -p 2424 -p 2480 broadinstitute/orientdb:latest
```

The same applies for the databases folder which if local to the running container would go away as soon as it died/you killed it.

The backup folder only needs to be mapped if you activate that setting on your [OrientDB][1] configuration file.

For more [Docker][2] information from the makers of [OrientDB][1], check out https://github.com/orientechnologies/orientdb-docker/wiki.

Included in this repository is also a `docker-compose.yml` file for use with [Docker Compose][4] that will make running the container much easier.

Running the orientdb console
----------------------------

```bash
docker run --rm -it \
  -v $CONFIG_PATH:/opt/orientdb/config \
  -v $DATABASES_PATH:/opt/orientdb/databases \
  -v $BACKUP_PATH:/opt/orientdb/backup \
  broadinstitute/orientdb:latest \
  /opt/orientdb/bin/console.sh
```

[1]: http://www.orientdb.org "OrientDB"
[2]: https://www.docker.com/ "Docker"
[3]: http://phusion.github.io/baseimage-docker/ "Phusion Baseimage"
[4]: https://docs.docker.com/compose/ "Docker Compose"
