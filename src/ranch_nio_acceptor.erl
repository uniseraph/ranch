-module(ranch_nio_acceptor).
-behaviour(gen_server).
-define(SERVER, ?MODULE).

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([start_link/3]).

%% ------------------------------------------------------------------
%% gen_server Function Exports
%% ------------------------------------------------------------------

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {listener,       % Listening socket
                acceptor,       % Asynchronous acceptor's internal reference
                module,          % FSM handling module
                conns_sup,
                transport
                                                                      }).
%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

-spec start_link(inet:socket(), module(), pid())
	-> {ok, pid()}.
start_link(LSocket, Transport, ConnsSup) ->
	gen_server:start_link(?MODULE, loop, [LSocket, Transport, ConnsSup]).

%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------

init([LSocket,Transport,ConnsSup]) ->
    process_flag(trap_exit, true),
    {ok, Ref} = prim_inet:async_accept(LSocket, -1),
    {ok, #state{listener = LSocket,acceptor = Ref,conns_sup=ConnsSup,transport=Transport}}.


handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({inet_async, LSock, Ref, {ok, CSocket}},
                #state{listener=LSock,transport=Transport, acceptor=Ref, conns_sup=ConnsSup} = State) ->
  try 
			 Transport:controlling_process(CSocket, ConnsSup),
       {ok,Pid}=ranch_conns_sup:start_protocol(ConnsSup, CSocket),
      case prim_inet:async_accept(LSock, -1) of
        {ok,    NewRef} -> 
                  {noreply, State#state{acceptor=NewRef}};
        {error, NewRef} -> exit({async_accept, inet:format_error(NewRef)})
      end
                                                                                                                                                             
  catch exit:Why ->   
        error_logger:error_msg("Error in async accept: ~p.\n", [Why]),
        {stop, Why, State}
                                                                                                                                                                       end;                                                                                                                                                                                                                                                                                                                                                                         
                                                                                                                                                                     handle_info({inet_async, ListSock, Ref, Error}, #state{listener=ListSock, acceptor=Ref} = State) ->
                                                                                                                                                                       {stop, Error, State};
                                                                                                                                                                    handle_info(_Info, State) ->    {noreply, State}.

terminate(_Reason, State) ->
  gen_tcp:close(State#state.listener),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

