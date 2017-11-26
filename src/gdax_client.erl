-module(gdax_client).

%% API exports
-export([test/0]).

%%====================================================================
%% API functions
%%====================================================================


test() ->
  application:ensure_all_started(gun),
  application:set_env(gdax_client, gdax_addr, "ws-feed.gdax.com"),
  application:set_env(gdax_client, gdax_port, 443),
  gdax_chan:start_link(fun(Data) -> io:format("GDAX GOT: ~p~n", [Data]) end).

%%====================================================================
%% Internal functions
%%====================================================================
