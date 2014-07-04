#!/bin/bash

set -e -E -u -o pipefail -o noclobber -o noglob -o braceexpand || exit 1
trap 'printf "[ee] failed: %s\n" "${BASH_COMMAND}" >&2' ERR || exit 1

test "${#}" -eq 0

cd -- "$( dirname -- "$( readlink -e -- "${0}" )" )"
test -d "${_generate_outputs}"

mkdir "${_generate_outputs}/build"

( cd -- ./repositories/erlang-js ; exec find . -not -name '.git' -print0 ; ) \
| ( cd -- ./repositories/erlang-js ; exec cpio -p -0 --quiet -- "${_generate_outputs}/build" ; )
chmod -R a=rX,u=rwX -- "${_generate_outputs}/build"

make -C "${_generate_outputs}/build/c_src" clean
make -C "${_generate_outputs}/build/c_src" js

gcc -shared -o "${_generate_outputs}/erlang_js_drv.so" \
		-L "${_generate_outputs}/build/c_src/system/lib" \
		-I "${_generate_outputs}/build/c_src/system/include/js" \
		-I "${_generate_outputs}/build/c_src/system/include/nspr" \
		-I "${_generate_outputs}/build/c_src" \
		-I "${pallur_pkg_erlang:-/usr/lib/erlang}/usr/include" \
		-L "${pallur_pkg_erlang:-/usr/lib/erlang}/usr/lib" \
		-w \
		${pallur_CFLAGS:-} ${pallur_LDFLAGS:-} \
		-DXP_UNIX \
		"${_generate_outputs}/build/c_src/"{driver_comm.c,spidermonkey.c,spidermonkey_drv.c} \
		"${_generate_outputs}/build/c_src/system/lib/"{libjs.a,libnspr4.a} \
		${pallur_LIBS:-}

exit 0
