
-module (mosaic_riak_kv_callbacks).

-behaviour (mosaic_component_callbacks).


-export ([configure/0]).
-export ([init/0, terminate/2, handle_call/5, handle_cast/4, handle_info/2]).


-import (mosaic_enforcements, [enforce_ok/1, enforce_ok_1/1]).


-record (state, {status}).


init () ->
	_ = erlang:send_after (100, erlang:self (), {mosaic_riak_kv_callbacks_internals, trigger_initialize}),
	State = #state{status = initializing},
	{ok, State}.


terminate (_Reason, _State = #state{}) ->
	ok = stop_applications (),
	ok.


handle_call (Operation, Inputs, _Data, _Sender, State = #state{}) ->
	ok = mosaic_transcript:trace_error ("received invalid call request; ignoring!", [{operation, Operation}, {inputs, Inputs}]),
	{reply, {error, {invalid_operation, Operation}}, State}.


handle_cast (Operation, Inputs, _Data, State = #state{}) ->
	ok = mosaic_transcript:trace_error ("received invalid cast request; ignoring!", [{operation, Operation}, {inputs, Inputs}]),
	{noreply, State}.


handle_info ({mosaic_riak_kv_callbacks_internals, trigger_initialize}, OldState = #state{status = initializing}) ->
	try
		Identifier = enforce_ok_1 (mosaic_generic_coders:os_env_get (mosaic_component_identifier,
					{decode, fun mosaic_component_coders:decode_component/1}, {error, missing_identifier})),
		IdentifierString = erlang:binary_to_list (enforce_ok_1 (mosaic_component_coders:encode_component (Identifier))),
		AppEnvGroup = enforce_ok_1 (mosaic_generic_coders:application_env_get (group, mosaic_riak_kv,
					{decode, fun mosaic_component_coders:decode_group/1}, {default, undefined})),
		OsEnvGroup = enforce_ok_1 (mosaic_generic_coders:os_env_get (mosaic_component_group,
					{decode, fun mosaic_component_coders:decode_group/1}, {default, undefined})),
		ok = enforce_ok (application:set_env (mosaic_riak_kv, identifier, Identifier)),
		ok = enforce_ok (start_applications ()),
		ok = if
			(OsEnvGroup =/= undefined) ->
				%ok = enforce_ok (mosaic_component_callbacks:register (OsEnvGroup)),
				ok;
			(AppEnvGroup =/= undefined) ->
				%ok = enforce_ok (mosaic_component_callbacks:register (AppEnvGroup)),
				ok;
			(AppEnvGroup =:= undefined), (OsEnvGroup =:= undefined) ->
				ok
		end,
		{noreply, OldState#state{status = executing}}
	catch throw : {error, Reason} -> {stop, Reason, OldState} end;
	
handle_info (Message, State = #state{}) ->
	ok = mosaic_transcript:trace_error ("received invalid message; terminating!", [{message, Message}]),
	{stop, {error, {invalid_message, Message}}, State}.


configure () ->
	try
		ok = enforce_ok (load_applications ()),
		HarnessInputDescriptor = enforce_ok_1 (mosaic_generic_coders:os_env_get (mosaic_component_harness_input_descriptor,
					{decode, fun mosaic_generic_coders:decode_integer/1}, {error, missing_harness_input_descriptor})),
		HarnessOutputDescriptor = enforce_ok_1 (mosaic_generic_coders:os_env_get (mosaic_component_harness_output_descriptor,
					{decode, fun mosaic_generic_coders:decode_integer/1}, {error, missing_harness_output_descriptor})),
		ok = enforce_ok (application:set_env (mosaic_component, callbacks, mosaic_riak_kv_callbacks)),
		ok = enforce_ok (application:set_env (mosaic_component, harness_input_descriptor, HarnessInputDescriptor)),
		ok = enforce_ok (application:set_env (mosaic_component, harness_output_descriptor, HarnessOutputDescriptor)),
		ok
	catch throw : Error = {error, _Reason} -> Error end.


resolve_applications () ->
	{ok, [
				sasl, os_mon, inets, crypto,
				% riak_err, cluster_info,
				mochiweb, webmachine, basho_stats,
				riak_core,
				bitcask, luke, erlang_js,
				riak_kv,
				skerl, luwak]}.


load_applications () ->
	try
		ok = enforce_ok (mosaic_application_tools:load (mosaic_riak_kv, with_dependencies)),
		Applications = enforce_ok_1 (resolve_applications ()),
		ok = enforce_ok (mosaic_application_tools:load (Applications, without_dependencies)),
		ok
	catch throw : Error = {error, _Reason} -> Error end.


start_applications () ->
	try
		Applications = enforce_ok_1 (resolve_applications ()),
		ok = enforce_ok (mosaic_application_tools:start (Applications, without_dependencies)),
		ok = enforce_ok (mosaic_application_tools:start (mosaic_riak_kv, with_dependencies)),
		ok
	catch throw : Error = {error, _Reason} -> Error end.


stop_applications () ->
	try
		ok
	catch _ : Reason -> {error, Reason} end.
