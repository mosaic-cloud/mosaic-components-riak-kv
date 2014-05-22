#!/bin/bash

set -e -E -u -o pipefail -o noclobber -o noglob -o braceexpand || exit 1
trap 'printf "[ee] failed: %s\n" "${BASH_COMMAND}" >&2' ERR || exit 1

test "${#}" -eq 0

cd -- "$( dirname -- "$( readlink -e -- "${0}" )" )"
test -d ./.generated

gcc -shared -o ./.generated/skerl_nifs.so \
		-I ./repositories/bitcask/c_src \
		-I "${pallur_pkg_erlang:-/usr/lib/erlang}/usr/include" \
		-L "${pallur_pkg_erlang:-/usr/lib/erlang}/usr/lib" \
		${pallur_CFLAGS:-} ${pallur_LDFLAGS:-} \
		./repositories/skerl/c_src/{skein_api.c,skein_block.c,skein.c,skein_debug.c,skerl_nifs.c} \
		${pallur_LIBS:-}

exit 0
