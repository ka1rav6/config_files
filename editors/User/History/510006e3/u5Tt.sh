#!/usr/bin/env bash

#script to move every header to include/ and then change the cmakelists accordingly

mkdir include/
cd src/
mv *.h ../include/

cd ..



file="$1"

sed -Ei 's#src/([^"]+\.h)#include/\1#g' "$file"