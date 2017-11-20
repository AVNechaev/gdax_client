-module(gdax_client).

%% API exports
-export([test/0]).

%%====================================================================
%% API functions
%%====================================================================


test() ->
  application:ensure_all_started(gun),
  {ok, ConnPid} = gun:open("ws-feed.gdax.com", 443, #{transport => ssl, protocols => [http]}),
  {ok,_} = gun:await_up(ConnPid),
  gun:ws_upgrade(ConnPid, "/"),
  ConnPid.

%%====================================================================
%% Internal functions
%%====================================================================
