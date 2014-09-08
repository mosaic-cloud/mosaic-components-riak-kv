#!/bin/bash

set -e -E -u -o pipefail -o noclobber -o noglob -o braceexpand || exit 1
trap 'printf "[ee] failed: %s\n" "${BASH_COMMAND}" >&2' ERR || exit 1

test "${#}" -eq 0

cd -- "$( dirname -- "$( readlink -e -- "${0}" )" )"
test -d "${_generate_outputs}"

gcc -shared -o "${_generate_outputs}/erlang_js_drv.so" \
		-I "${pallur_pkg_js_1_8_0}/include/js" \
		-L "${pallur_pkg_js_1_8_0}/lib" \
		-I "${pallur_pkg_nspr_4_8}/include" \
		-L "${pallur_pkg_nspr_4_8}/lib" \
		-I "${pallur_pkg_erlang:-/usr/lib/erlang}/usr/include" \
		-L "${pallur_pkg_erlang:-/usr/lib/erlang}/usr/lib" \
		-DXP_UNIX \
		-w \
		${pallur_CFLAGS:-} ${pallur_LDFLAGS:-} \
		./repositories/erlang-js/c_src/{driver_comm.c,spidermonkey.c,spidermonkey_drv.c} \
		${pallur_LIBS:-} \
		-Wl,-Bstatic -ljs -lnspr4 -Wl,-Bdynamic \
		-Wl,-Bstatic -lstdc++ -Wl,-Bdynamic \
		-static-libgcc -static-libstdc++

exit 0
