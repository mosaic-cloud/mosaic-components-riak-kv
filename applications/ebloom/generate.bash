#!/bin/bash

set -e -E -u -o pipefail || exit 1
test "${#}" -eq 0

cd -- "$( dirname -- "$( readlink -e -- "${0}" )" )"

rm -Rf ./.generated
mkdir ./.generated

gcc -shared -o ./.generated/ebloom_nifs.so \
		-I ./repositories/ebloom/c_src \
		-I /usr/lib/erlang/usr/include \
		./repositories/ebloom/c_src/ebloom_nifs.cpp

exit 0
