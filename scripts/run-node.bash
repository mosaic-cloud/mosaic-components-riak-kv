#!/dev/null

if ! test "${#}" -le 1 ; then
	echo "[ee] invalid arguments; aborting!" >&2
	exit 1
fi

if test "${#}" -eq 0 ; then
	_identifier="0000000000000000000000000000000000000000"
else
	_identifier="${1}"
fi

_erl_argv=(
	"${_erl}"
		"${_erl_args[@]}"
		-noinput -noshell
		-sname "mosaic-riak-kv-${_identifier}@${_erl_host}" -setcookie "${_erl_cookie}"
		-boot start_sasl
		-config "${_outputs}/erlang/applications/mosaic_riak_kv/priv/mosaic_riak_kv.config"
		-run mosaic_component_app boot
)

mosaic_component_identifier="${_identifier}" \
mosaic_component_harness_input_descriptor=3 \
mosaic_component_harness_output_descriptor=4 \
ERL_EPMD_PORT="${_erl_epmd_port}" \
exec "${_erl_argv[@]}" 3<&0- 4>&1- </dev/null >&2