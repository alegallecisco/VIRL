#!/bin/bash
## Script to show all assosciated child relations to containers
## Requires image ID as argument

for i in $(docker images -q)
do
    docker history $i | grep -q $? && echo $i
done | sort -u
