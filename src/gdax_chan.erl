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
-export([start_link/1]).

%% gen_server callbacks
-export([init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3]).

-define(SERVER, ?MODULE).

-type gdax_tick() :: #{
  instr => binary(),
  time => pos_integer(),
  last_price => float()
 }.

-type tick_fun() :: fun((Tick :: gdax_tick()) -> ok).

-export_type([gdax_tick/0, tick_fun/0]).

-record(state, {
  conn_id :: pid(),
  tick_fun :: tick_fun()
}).

-compile([{parse_transform, lager_transform}]).
%%%===================================================================
%%% API
%%%===================================================================
-spec(start_link(TickFun :: tick_fun()) -> {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link(TickFun) ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [TickFun], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================
init([TickFun]) ->
  GDAXAddr = rz_util:get_env(gdax_client, gdax_addr),
  GDAXPort = rz_util:get_env(gdax_client, gdax_port),
  {ok, ConnPid} = gun:open(GDAXAddr, GDAXPort, #{transport => ssl, protocols => [http]}),
%%  {ok, H} = file:open("/home/an/gdax.log", [append, raw, binary]),
%%  file:write(H, io_lib:format("--- LOG STARTED AT ~p ---~n", [erlang:localtime()])),
  {ok, #state{conn_id = ConnPid, tick_fun = TickFun}}.

%%--------------------------------------------------------------------
handle_info({gun_up, _, http}, State) -> do_upgrade_chan(State);
handle_info({gun_ws_upgrade, _, _, _}, State) -> do_subscribe(State);
handle_info({gun_ws, _, Msg}, State) -> do_message(Msg, State);
handle_info(Other, State) ->
  lager:debug("GDAX MSG: ~p", [Other]),
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
  {noreply, State}.

do_subscribe(State = #state{conn_id = ConnId}) ->
  {ok, D} = file:read_file("/home/an/req"),
  gun:ws_send(ConnId, {text, D}),
  {noreply, State}.

do_message({text, Data}, State = #state{tick_fun = TF}) ->
  case jiffy:decode(Data, [return_maps]) of
    #{
      <<"type">> := <<"ticker">>,
      <<"product_id">> := Pair,
      <<"price">> := Price,
      <<"time">> := Time} ->
      TF(#{instr = Pair, last_price = Price, time = Time});
    _ ->
      ok
  end,
  {noreply, State}.