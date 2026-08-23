#!/usr/bin/env bash

#script to move every header to include/ and then change the cmakelists accordingly

file="$1"

sed -Ei 's#src/([^"]+\.h)#include/\1#g' "$file"