#!/bin/bash

track=$1
output=tracks/$track.png

[ -z "$1" ] && echo "missing track argument" && exit 1
[ -f $output ] && exit

remote=https://assets.exercism.org/tracks/$track.svg

mkdir -p tracks
curl $remote | rsvg-convert -h 150 > $output
