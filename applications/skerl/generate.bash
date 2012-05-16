#!/bin/bash

set -e -E -u -o pipefail || exit 1
test "${#}" -eq 0

cd -- "$( dirname -- "$( readlink -e -- "${0}" )" )"

rm -Rf ./.generated
mkdir ./.generated

gcc -shared -o ./.generated/skerl_nifs.so \
		-I ./repositories/bitcask/c_src \
		-I "${mosaic_pkg_erlang:-/usr/lib/erlang}/usr/include" \
		-L "${mosaic_pkg_erlang:-/usr/lib/erlang}/usr/lib" \
		${mosaic_CFLAGS:-} ${mosaic_LDFLAGS:-} \
		./repositories/skerl/c_src/{skein_api.c,skein_block.c,skein.c,skein_debug.c,skerl_nifs.c} \
		${mosaic_LIBS:-}

exit 0
