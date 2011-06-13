#!/bin/bash

set -e -E -u -o pipefail || exit 1
test "${#}" -eq 0

cd -- "$( dirname -- "$( readlink -e -- "${0}" )" )"

rm -Rf ./.generated
mkdir ./.generated

cp -T ./repositories/cluster-info/src/cluster_info.app.src ./.generated/cluster_info.app

exit 0
