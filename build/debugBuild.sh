#!/bin/bash
mkdir -p output
docker run --privileged -it --rm -v $(pwd)/output:/output -v $(pwd)/supportFiles:/supportFiles:ro -w /supportFiles debian:buster
