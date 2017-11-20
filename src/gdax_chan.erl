 %%%-------------------------------------------------------------------
%%% @author an
%%% @copyright (C) 2017, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. Nov 2017 14:39
%%%-------------------------------------------------------------------
-module(gdax_chan).
-author("an").

-behaviour(gen_server).

%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {
  conn_id :: pid(),
  log_h :: io:device()}).
-compile([{parse_transform, lager_transform}]).
%%%===================================================================
%%% API
%%%===================================================================
-spec(start_link() ->
  {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================
 init([]) ->
%%  GDAXAddr = rz_util:get_env(gdax_client, gdax_addr),
%%  GDAXPort = rz_util:get_env(gdax_client, gdax_port),
   application:ensure_all_started(gun),
   GDAXAddr = "ws-feed.gdax.com",
   GDAXPort =443,
  {ok, ConnPid} = gun:open(GDAXAddr, GDAXPort, #{transport => ssl, protocols => [http]}),
  {ok, H} = file:open("/home/an/gdax.log", [append, raw, binary]),
  file:write(H, io_lib:format("--- LOG STARTED AT ~p ---~n", [erlang:localtime()])),
  {ok, #state{conn_id = ConnPid, log_h = H}}.

%%--------------------------------------------------------------------
handle_info({gun_up, _, http}, State) -> do_upgrade_chan(State);
handle_info({gun_ws_upgrade, _, _, _}, State) -> do_subscribe(State);
handle_info({gun_ws, _, Msg}, State) -> do_message(Msg, State);
handle_info(Other, State) ->
  file:write(State#state.log_h, io_lib:format("MSG: ~p", [Other])),
  file:write(State#state.log_h, io_lib:nl()),
  {noreply, State}.
%%--------------------------------------------------------------------
handle_call(_Request, _From, _State) -> exit(handle_call_unsupported).
handle_cast(_Request, _State) -> exit(handle_cast_unsupported).
terminate(_Reason, _State) -> ok.
code_change(_OldVsn, State, _Extra) -> {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
do_upgrade_chan(State = #state{conn_id = ConnId}) ->
  gun:ws_upgrade(ConnId, "/"),
  file:write(State#state.log_h, [io_lib:nl(), "---RESTART---", io_lib:nl()]),
  {noreply, State}.

do_subscribe(State = #state{conn_id = ConnId}) ->
  {ok, D} = file:read_file("/home/an/req"),
  gun:ws_send(ConnId, {text, D}),
  {noreply, State}.

do_message({text, Data}, State = #state{log_h = H}) ->
  case jiffy:decode(Data, [return_maps]) of
    #{
      <<"type">> := <<"ticker">>,
      <<"product_id">> := Pair,
      <<"price">> := Price,
      <<"time">> := Time} ->
      file:write(H, io_lib:format("TICK: ~s: ~s: ~s~n", [Pair, Price, Time]));
    _ ->
      file:write(H, Data),
      file:write(H, io_lib:nl())
  end,
  {noreply, State}.