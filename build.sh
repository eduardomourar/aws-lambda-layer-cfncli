#!/bin/bash

docker build -t cfncli . --build-arg DOCKER_MIRROR=${DOCKER_MIRROR-''}
CONTAINER=$(docker run -d cfncli:latest false)
docker cp ${CONTAINER}:/root/layer.zip layer.zip
docker cp ${CONTAINER}:/root/VERSION VERSION
