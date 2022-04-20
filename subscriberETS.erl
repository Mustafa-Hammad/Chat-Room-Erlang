-module(subscriberETS).
-export([start/0, connect/3, disconnect/2, get_online_users/1, get_all_sockets/1, get_socket/2, stop/1]).


start() ->
    ets:new(subscriber, [public]).

connect(Client, Username, Socket) ->
    ets:insert_new(Client, {Username, Socket}).

get_online_users(Client) ->
    ets:match(Client, {'$1', '_'}).

get_all_sockets(Client) ->
    ets:match(Client, {'_', '$1'}).

get_socket(Subsciber, Username) ->
    ets:lookup_element(Subsciber, Username, 2).

disconnect(Client, Username) ->
    ets:delete(Client, Username).
    
stop(Client) ->
    ets:delete(Client).
