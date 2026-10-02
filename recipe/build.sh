#!/usr/bin/env bash
set -o xtrace -o nounset -o pipefail -o errexit

# ─── shared ─────────────────────────────────────────────────────────────────
# conda's SRC_DIR overrides common.mk:20 `SRC_DIR ?= src`, so :86 misses .prepared and clones into a non-empty dir
src_root="${SRC_DIR}"
unset SRC_DIR
# modules are built by a nested make spawned from scripts/build.sh; jobserver tokens don't survive that, so -j must come from the environment
export MAKEFLAGS="-j${CPU_COUNT}"
# both spellings are read: lowercase by LibMR/Makefile:76 and build/hiredis/Makefile:52, uppercase by core src/Makefile:271 and redisearch's deps/hiredis/Makefile:113
export openssl_prefix="${PREFIX}" OPENSSL_PREFIX="${PREFIX}"

# ─── redisearch (search) ────────────────────────────────────────────────────
export IGNORE_MISSING_DEPS=1
export CMAKE_ARGS="${CMAKE_ARGS:-} -DCMAKE_C_COMPILER=${CC} -DCMAKE_CXX_COMPILER=${CXX} -DBOOST_DIR=${PREFIX} -DBoost_INCLUDE_DIR=${PREFIX}/include"
if [[ "${target_platform}" == osx-* ]]; then
  mkdir -p "${PWD}/.libtool-shim"
  ln -sf "${BUILD_PREFIX}/bin/${LIBTOOL}" "${PWD}/.libtool-shim/libtool"
  export PATH="${PWD}/.libtool-shim:${PATH}"
fi
search_args=(
  LTO=0
)

# ─── redisjson (ReJSON) and redisearch's Rust ffi ───────────────────────────
export LIBCLANG_PATH="${BUILD_PREFIX}/lib"
# conda's rust activation exports CARGO_BUILD_TARGET, which nests cargo's output under the
# triple, while redisjson's Makefile:194 copies from Makefile:129's un-nested target/release.
# Upstream scrubs the same var for the same cp failure in redisearch's tests/deps/setup_rejson.sh:78.
# Harmless for redisearch: build.sh:721 only passes -DCARGO_BUILD_TARGET on when it is set, and
# src/redisearch_rs/CMakeLists.txt:49 keys the artifact dir off that.
unset CARGO_BUILD_TARGET

# ─── redistimeseries ────────────────────────────────────────────────────────
timeseries_args=(
  "CONFIGURE_FLAGS=--disable-libevent-regress --disable-samples"
)

make deploy PREFIX="${PREFIX}" CC="${CC}" CXX="${CXX}" LD="${CC}" \
  BUILD_TLS=yes "${search_args[@]}" "${timeseries_args[@]}"

# ─── crate licenses ─────────────────────────────────────────────────────────
(cd modules/redisjson/src && cargo-bundle-licenses --format yaml --output "${src_root}/THIRDPARTY-redisjson.yml")
(cd modules/redisearch/src/src/redisearch_rs && cargo-bundle-licenses --format yaml --output "${src_root}/THIRDPARTY-redisearch.yml")

mkdir -p "${PREFIX}/etc"
install -m0644 redis.conf "${PREFIX}/etc/redis.conf"
install -m0644 sentinel.conf "${PREFIX}/etc/redis-sentinel.conf"
