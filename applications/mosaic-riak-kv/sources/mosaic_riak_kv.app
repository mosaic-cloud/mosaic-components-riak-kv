
{application, mosaic_riak_kv, [
	{description, "mOSAIC Riak KV component"},
	{vsn, "1"},
	{applications, [kernel, stdlib, mosaic_tools, mosaic_harness, mosaic_component]},
	{modules, []},
	{registered, []},
	{mod, {mosaic_dummy_app, defaults}},
	{env, []}
]}.
