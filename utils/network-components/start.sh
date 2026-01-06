#!/bin/bash
# [ Build ]
dest="/opt/network-components"
docker build "${dest}/docker-images/alpine-image/" -t alpine-user
docker build "${dest}/docker-images/containernet-image/" -t containernet
docker build "${dest}/docker-images/onos-image/" -t onos-controller

# [ Start -> Onos -> Controller ]
docker run -d --name onos --restart always -p 8181:8181 -p 6633:6633 -p 6653:6653 onos-controller

# [ Start -> Containernet -> Network Topology ]
docker run -d --name containernet -it --rm --privileged --pid='host' -v /var/run/docker.sock:/var/run/docker.sock --mount type=bind,source="${dest}/topology",target=/netlabautoops containernet python3 /netlabautoops/topology.py