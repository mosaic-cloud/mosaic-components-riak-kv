#!/bin/bash

set -e -E -u -o pipefail || exit 1
test "${#}" -eq 0

cd -- "$( dirname -- "$( readlink -e -- "${0}" )" )"

rm -Rf ./.generated
mkdir ./.generated

gcc -shared -o ./.generated/ebloom_nifs.so \
		-I ./repositories/ebloom/c_src \
		-I "${mosaic_pkg_erlang:-/usr/lib/erlang}/usr/include" \
		-L "${mosaic_pkg_erlang:-/usr/lib/erlang}/usr/lib" \
		${mosaic_CFLAGS:-} ${mosaic_LDFLAGS:-} \
		./repositories/ebloom/c_src/ebloom_nifs.cpp \
		-lstdc++ \
		${mosaic_LIBS:-}

exit 0
