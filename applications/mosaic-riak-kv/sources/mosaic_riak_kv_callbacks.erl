
-module (mosaic_riak_kv_callbacks).

-behaviour (mosaic_component_callbacks).


-export ([configure/0]).
-export ([init/0, terminate/2, handle_call/5, handle_cast/4, handle_info/2]).


-import (mosaic_enforcements, [enforce_ok/1, enforce_ok_1/1, enforce_ok_2/1]).


-record (state, {status, identifier, group, store_http_socket, store_pb_socket, handoff_socket, join_timer}).


init () ->
	try
		State = #state{
					status = waiting_initialize,
					identifier = none, group = none,
					store_http_socket = none, store_pb_socket = none, handoff_socket = none,
					join_timer = none},
		erlang:self () ! {mosaic_riak_kv_callbacks_internals, trigger_initialize},
		{ok, State}
	catch throw : {error, Reason} -> {stop, Reason} end.


terminate (_Reason, _State = #state{}) ->
	ok = stop_applications_async (),
	ok.


handle_call (<<"mosaic-riak-kv:get-store-http-endpoint">>, null, <<>>, _Sender, State = #state{status = executing, store_http_socket = Socket}) ->
	{SocketIp, SocketPort} = Socket,
	Outcome = {ok, {struct, [
					{<<"ip">>, SocketIp}, {<<"port">>, SocketPort},
					{<<"url">>, erlang:iolist_to_binary (["http://", SocketIp, ":", erlang:integer_to_list (SocketPort), "/"])}
				]}, <<>>},
	{reply, Outcome, State};
	
handle_call (<<"mosaic-riak-kv:get-store-pb-endpoint">>, null, <<>>, _Sender, State = #state{status = executing, store_pb_socket = Socket}) ->
	{SocketIp, SocketPort} = Socket,
	Outcome = {ok, {struct, [
					{<<"ip">>, SocketIp}, {<<"port">>, SocketPort},
					{<<"url">>, erlang:iolist_to_binary (["riak://", SocketIp, ":", erlang:integer_to_list (SocketPort), "/"])}
				]}, <<>>},
	{reply, Outcome, State};
	
handle_call (<<"mosaic-riak-kv:get-handoff-endpoint">>, null, <<>>, _Sender, State = #state{status = executing, handoff_socket = Socket}) ->
	{SocketIp, SocketPort} = Socket,
	Outcome = {ok, {struct, [
					{<<"ip">>, SocketIp}, {<<"port">>, SocketPort}
				]}, <<>>},
	{reply, Outcome, State};
	
handle_call (<<"mosaic-riak-kv:get-node-identifier">>, null, <<>>, _Sender, State) ->
	Outcome = {ok, erlang:atom_to_binary (erlang:node (), utf8), <<>>},
	{reply, Outcome, State};
	
handle_call (Operation, Inputs, _Data, _Sender, State = #state{status = executing}) ->
	ok = mosaic_transcript:trace_error ("received invalid call request; ignoring!", [{operation, Operation}, {inputs, Inputs}]),
	{reply, {error, {invalid_operation, Operation}}, State};
	
handle_call (Operation, Inputs, _Data, _Sender, State = #state{status = Status})
		when (Status =/= executing) ->
	ok = mosaic_transcript:trace_error ("received invalid call request; ignoring!", [{operation, Operation}, {inputs, Inputs}, {status, Status}]),
	{reply, {error, {invalid_status, Status}}, State}.


handle_cast (Operation, Inputs, _Data, State = #state{status = executing}) ->
	ok = mosaic_transcript:trace_error ("received invalid cast request; ignoring!", [{operation, Operation}, {inputs, Inputs}]),
	{noreply, State};
	
handle_cast (Operation, Inputs, _Data, State = #state{status = Status})
		when (Status =/= executing) ->
	ok = mosaic_transcript:trace_error ("received invalid cast request; ignoring!", [{operation, Operation}, {inputs, Inputs}, {status, Status}]),
	{noreply, State}.


handle_info ({mosaic_riak_kv_callbacks_internals, trigger_initialize}, OldState = #state{status = waiting_initialize}) ->
	try
		Identifier = enforce_ok_1 (mosaic_generic_coders:application_env_get (identifier, mosaic_riak_kv,
					{decode, fun mosaic_component_coders:decode_component/1}, {error, missing_identifier})),
		Group = enforce_ok_1 (mosaic_generic_coders:application_env_get (group, mosaic_riak_kv,
					{decode, fun mosaic_component_coders:decode_group/1}, {error, missing_group})),
		ok = enforce_ok (mosaic_component_callbacks:acquire_async (
					[{<<"store_http_socket">>, <<"socket:ipv4:tcp">>}, {<<"store_pb_socket">>, <<"socket:ipv4:tcp">>},
								{<<"handoff_socket">>, <<"socket:ipv4:tcp">>}],
					{mosaic_riak_kv_callbacks_internals, acquire_return})),
		NewState = OldState#state{status = waiting_acquire_return, identifier = Identifier, group = Group},
		{noreply, NewState}
	catch throw : Error = {error, _Reason} -> {stop, Error, OldState} end;
	
handle_info ({{mosaic_riak_kv_callbacks_internals, acquire_return}, Outcome}, OldState = #state{status = waiting_acquire_return, identifier = Identifier, group = Group}) ->
	try
		Descriptors = enforce_ok_1 (Outcome),
		[StoreHttpSocket, StorePbSocket, HandoffSocket] = enforce_ok_1 (mosaic_component_coders:decode_socket_ipv4_tcp_descriptors (
					[<<"store_http_socket">>, <<"store_pb_socket">>, <<"handoff_socket">>], Descriptors)),
		{StoreHttpSocketIp, StoreHttpSocketPort} = StoreHttpSocket,
		{StorePbSocketIp, StorePbSocketPort} = StorePbSocket,
		{HandoffSocketIp, HandoffSocketPort} = HandoffSocket,
		IdentifierString = erlang:binary_to_list (enforce_ok_1 (mosaic_component_coders:encode_component (Identifier))),
		StoreHttpSocketIpString = erlang:binary_to_list (StoreHttpSocketIp),
		StorePbSocketIpString = erlang:binary_to_list (StorePbSocketIp),
		HandoffSocketIpString = erlang:binary_to_list (HandoffSocketIp),
		ok = enforce_ok (application:set_env (riak_core, handoff_ip, HandoffSocketIpString)),
		ok = enforce_ok (application:set_env (riak_core, handoff_port, HandoffSocketPort)),
		ok = enforce_ok (application:set_env (riak_core, http, [{StoreHttpSocketIpString, StoreHttpSocketPort}])),
		ok = enforce_ok (application:set_env (riak_kv, pb_ip, StorePbSocketIpString)),
		ok = enforce_ok (application:set_env (riak_kv, pb_port, StorePbSocketPort)),
		ok = enforce_ok (application:set_env (riak_core, ring_state_dir, "/tmp/mosaic/components/mosaic-riak-kv/" ++ IdentifierString ++ "/ring")),
		ok = enforce_ok (application:set_env (riak_kv, mapred_queue_dir, "/tmp/mosaic/components/mosaic-riak-kv/" ++ IdentifierString ++ "/mapred")),
		ok = enforce_ok (application:set_env (bitcask, data_root, "/tmp/mosaic/components/mosaic-riak-kv/" ++ IdentifierString ++ "/bitcask")),
		ok = enforce_ok (start_applications ()),
		ok = enforce_ok (mosaic_component_callbacks:register_async (Group, {mosaic_riak_kv_callbacks_internals, register_return})),
		NewState = OldState#state{status = waiting_register_return, store_http_socket = StoreHttpSocket, store_pb_socket = StorePbSocket, handoff_socket = HandoffSocket},
		{noreply, NewState}
	catch throw : Error = {error, _Reason} -> {stop, Error, OldState} end;
	
handle_info ({{mosaic_riak_kv_callbacks_internals, register_return}, Outcome}, OldState = #state{status = waiting_register_return}) ->
	try
		ok = enforce_ok (Outcome),
		JoinTimer = enforce_ok_1 (timer:send_interval (5000, erlang:self (), {mosaic_riak_kv_callbacks_internals, trigger_join})),
		NewState = OldState#state{status = executing, join_timer = JoinTimer},
		{noreply, NewState}
	catch throw : Error = {error, _Reason} -> {stop, Error, OldState} end;
	
handle_info ({mosaic_riak_kv_callbacks_internals, trigger_join}, State = #state{status = executing, group = Group}) ->
	try
		ok = enforce_ok (mosaic_component_callbacks:call_async (Group, <<"mosaic-riak-kv:get-node-identifier">>, null, <<>>, {mosaic_riak_kv_callbacks_internals, join_call_return})),
		{noreply, State}
	catch throw : Error = {error, _Reason} -> {stop, Error, State} end;
	
handle_info ({{mosaic_riak_kv_callbacks_internals, join_call_return}, Outcome}, State = #state{status = executing}) ->
	ok = try
		EncodedNode = case Outcome of
			{ok, EncodedNode_, <<>>} when is_binary (EncodedNode_) -> EncodedNode_;
			{error, timeout} -> throw ({error, ignore});
			{ok, _Outputs, _Data} ->
				ok = mosaic_transcript:trace_warning ("invalid `mosaic-riak-kv:get-node-identifier` outcome; ignoring!"),
				throw ({error, ignore});
			{error, _Reason, _Data} ->
				% ok = mosaic_transcript:trace_warning ("failed `mosaic-riak-kv:get-node-identifier`; ignoring!"),
				throw ({error, ignore})
		end,
		Node = case erlang:binary_to_atom (EncodedNode, utf8) of
			Node_ when (Node_ =/= node ()) -> Node_;
			_ -> throw ({error, ignore})
		end,
		Connected = lists:member (Node, erlang:nodes ()),
		ok = if
			Connected -> throw ({error, ignore});
			true -> ok
		end,
		ok = mosaic_transcript:trace_information ("joining node...", [{node, Node}]),
		case riak_core_gossip:send_ring (Node) of
			ok -> ok;
			{error, Reason} ->
				ok = mosaic_transcript:trace_error ("failed joining node; ignoring!", [{node, Node}, {reason, Reason}]),
				throw ({error, ignore})
		end,
		ok
	catch throw : {error, ignore} -> ok end,
	{noreply, State};
	
handle_info (Message, State = #state{status = Status}) ->
	ok = mosaic_transcript:trace_error ("received invalid message; terminating!", [{message, Message}, {status, Status}]),
	{stop, {error, {invalid_message, Message}}, State}.


configure () ->
	try
		ok = enforce_ok (load_applications ()),
		AppEnvIdentifier = enforce_ok_1 (mosaic_generic_coders:application_env_get (identifier, mosaic_riak_kv,
					{decode, fun mosaic_component_coders:decode_component/1}, {default, undefined})),
		OsEnvIdentifier = enforce_ok_1 (mosaic_generic_coders:os_env_get (mosaic_component_identifier,
					{decode, fun mosaic_component_coders:decode_component/1}, {default, undefined})),
		AppEnvGroup = enforce_ok_1 (mosaic_generic_coders:application_env_get (group, mosaic_riak_kv,
					{decode, fun mosaic_component_coders:decode_group/1}, {default, undefined})),
		OsEnvGroup = enforce_ok_1 (mosaic_generic_coders:os_env_get (mosaic_component_group,
					{decode, fun mosaic_component_coders:decode_group/1}, {default, undefined})),
		HarnessInputDescriptor = enforce_ok_1 (mosaic_generic_coders:os_env_get (mosaic_component_harness_input_descriptor,
					{decode, fun mosaic_generic_coders:decode_integer/1}, {error, missing_harness_input_descriptor})),
		HarnessOutputDescriptor = enforce_ok_1 (mosaic_generic_coders:os_env_get (mosaic_component_harness_output_descriptor,
					{decode, fun mosaic_generic_coders:decode_integer/1}, {error, missing_harness_output_descriptor})),
		Identifier = if
			(OsEnvIdentifier =/= undefined) -> OsEnvIdentifier;
			(AppEnvIdentifier =/= undefined) -> AppEnvIdentifier;
			true -> throw ({error, missing_identifier})
		end,
		Group = if
			(OsEnvGroup =/= undefined) -> OsEnvGroup;
			(AppEnvGroup =/= undefined) -> AppEnvGroup;
			true -> throw ({error, missing_group})
		end,
		IdentifierString = erlang:binary_to_list (enforce_ok_1 (mosaic_component_coders:encode_component (Identifier))),
		GroupString = erlang:binary_to_list (enforce_ok_1 (mosaic_component_coders:encode_group (Group))),
		ok = enforce_ok (application:set_env (mosaic_riak_kv, identifier, IdentifierString)),
		ok = enforce_ok (application:set_env (mosaic_riak_kv, group, GroupString)),
		ok = enforce_ok (application:set_env (mosaic_component, harness_input_descriptor, HarnessInputDescriptor)),
		ok = enforce_ok (application:set_env (mosaic_component, harness_output_descriptor, HarnessOutputDescriptor)),
		ok
	catch throw : {error, Reason} -> {error, {failed_configuring, Reason}} end.


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
		enforce_ok (stop_applications (leave))
	catch
		throw : {error, Reason} ->
			ok = mosaic_tools:trace_error ("failed stopping applications...", [{reason, Reason}]),
			ok;
		_ : Reason ->
			ok = mosaic_tools:trace_error ("failed stopping applications...", [{reason, Reason}]),
			ok
	end.

stop_applications (leave) ->
	ok = enforce_ok (riak_core_gossip:remove_from_cluster (erlang:node ())),
	stop_applications ({wait, 60});
	
stop_applications ({wait, 0}) ->
	ok;
	
stop_applications ({wait, Counter}) ->
	case riak_status:ringready () of
		{ok, _Nodes} ->
			ok;
		{error, _Reason} ->
			ok = enforce_ok (timer:sleep (1000)),
			stop_applications ({wait, Counter - 1})
	end.

stop_applications_async () ->
	_ = erlang:spawn (
				fun () ->
					ok = timer:sleep (100),
					ok = stop_applications (),
					ok
				end),
	ok.