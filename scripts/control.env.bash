#!/dev/null

_identifier="${mosaic_component_identifier:-00000000d40764b8f0234b09fb799980063e83e6}"

_erl_args+=(
	-noshell -noinput
	-sname "mosaic-riak-kv-${_identifier}@localhost"
	-env mosaic_component_identifier "${_identifier}"
	-boot start_sasl
	-config "${_deployment_erlang_path}/lib/mosaic_riak_kv/priv/mosaic_riak_kv.config"
	-run mosaic_riak_kv_callbacks standalone
)

_ez_bundle_names=(
	basho_stats
	bitcask
	cluster_info
	ebloom
	eper
	erlang_js
	luke
	luwak
	mochiweb
	mosaic_component
	mosaic_harness
	mosaic_riak_kv
	mosaic_tools
	protobuffs
	riakc
	riak_core
	riak_err
	riak_kv
	skerl
	webmachine
)

_bundles_token=436d2c5d9b46d5ae336eabf38dc920a3
_bundles_base_url="http://data.volution.ro/ciprian/${_bundles_token}"
_bundles_base_path="/afs/olympus.volution.ro/people/ciprian/web/data/${_bundles_token}"
