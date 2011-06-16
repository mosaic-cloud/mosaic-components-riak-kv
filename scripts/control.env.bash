#!/dev/null

_erl_path=''

_erl_run_argv=(
	+Bd +Ww
	-env ERL_CRASH_DUMP /dev/null
	-env ERL_LIBS "${_deployment_erlang_path:-./erlang}/lib"
	-env LANG C
	-noshell -noinput
	-sname mosaic-riak-kv-0000000000000000000000000000000000000000@localhost
	-boot start_sasl
	-config "${_deployment_erlang_path:-./erlang}/lib/mosaic_riak_kv/priv/mosaic_riak_kv.config"
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
