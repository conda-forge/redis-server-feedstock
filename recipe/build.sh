#!/bin/bash

set -x

# When Redis-Stack modules are built the "readies" make-helper invokes
# cmake $(CMAKE_FLAGS) …
# (see deps/readies/mk/cmake.rules). 
# All items in $(CMAKE_FLAGS) are passed to the shell unquoted.
# the un-escaped semicolon in -DCMAKE_PROGRAM_PATH is interpreted by the shell as a command-separator
# thus we drop the second ${PREFIX}/bin
export CMAKE_ARGS=$(echo "$CMAKE_ARGS" \
  | sed "s@-DCMAKE_PROGRAM_PATH=${BUILD_PREFIX}/bin;${PREFIX}/bin@-DCMAKE_PROGRAM_PATH=${BUILD_PREFIX}/bin@" \
  | sed -E 's@-DCMAKE_FIND_ROOT_PATH=([^;]*);([^ ]*)@-DCMAKE_FIND_ROOT_PATH=\1\\;\2@g')


export BINDGEN_EXTRA_CLANG_ARGS="$CFLAGS"
export LIBCLANG_PATH=$BUILD_PREFIX/lib/libclang${SHLIB_EXT}


make PREFIX=$PREFIX BUILD_TLS=yes BUILD_WITH_MODULES=yes install

mkdir -p "${PREFIX}/etc"

mkdir -p "${PREFIX}/var/run/redis"
mkdir -p "${PREFIX}/var/db/redis"

sed -i -e "s:/var/run/redis_6379.pid:${PREFIX}/var/run/redis.pid:g" redis.conf
sed -i -e "s:dir ./:dir ${PREFIX}/var/db/redis/:g" redis.conf

cp redis.conf "${PREFIX}/etc/redis.conf"
cp sentinel.conf "${PREFIX}/etc/redis-sentinel.conf"
