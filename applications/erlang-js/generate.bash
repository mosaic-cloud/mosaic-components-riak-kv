#!/bin/bash

set -e -E -u -o pipefail || exit 1
test "${#}" -eq 0

cd -- "$( dirname -- "$( readlink -e -- "${0}" )" )"

rm -Rf ./.generated
mkdir ./.generated

make -C ./repositories/erlang-js/c_src clean
make -C ./repositories/erlang-js/c_src js

gcc -shared -o ./.generated/erlang_js_drv.so \
		-L ./repositories/erlang-js/c_src/system/lib \
		-I ./repositories/erlang-js/c_src/system/include/js \
		-I ./repositories/erlang-js/c_src/system/include/nspr \
		-I ./repositories/erlang-js/c_src \
		-I /usr/lib/erlang/usr/include \
		-DXP_UNIX \
		./repositories/erlang-js/c_src/{driver_comm.c,spidermonkey.c,spidermonkey_drv.c} \
		./repositories/erlang-js/c_src/system/lib/{libjs.a,libnspr4.a}

exit 0
