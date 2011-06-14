
{application, mosaic_riak_kv, [
	{description, "mOSAIC Riak KV component"},
	{vsn, "1"},
	{applications, [kernel, stdlib, mosaic_component, riak_kv]},
	{modules, []},
	{registered, []},
	{mod, {mosaic_dummy_app, defaults}},
	{env, []}
]}.
