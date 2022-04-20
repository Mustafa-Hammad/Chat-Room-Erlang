-module(client).
-export([start/1, send/1, rcv/1, client_try/4, client_try/2, client_try/3]).


start(Username) ->
    {ok, Socket} = gen_tcp:connect("localhost", 8000, [binary]),
    ok=gen_tcp:send(Socket, term_to_binary({register,Username})),
    ClientSendPID = spawn(client, send, [Socket]),
    ClientRecvPID = spawn(client, rcv, [Socket]),    
    register(Username, ClientSendPID),
    ok=gen_tcp:controlling_process(Socket, ClientRecvPID).

send(Socket) ->
    receive
        {send, Msg, OtherUsername} ->
            ok=gen_tcp:send(Socket, term_to_binary({send,Msg,OtherUsername})),
            send(Socket);

        {brodcast, Msg, Username} ->
            ok=gen_tcp:send(Socket, term_to_binary({brodcast, Msg, Username})),
            send(Socket);
        
        online ->
            ok=gen_tcp:send(Socket, term_to_binary(online)),
            send(Socket);
        
        stop ->
            gen_tcp:close(Socket)
    end.

rcv(Socket) ->
    receive
        {tcp, Socket, Bin} ->
            ServerReply = binary_to_term(Bin),
            server_reply(ServerReply),
            rcv(Socket);

        {tcp_closed, Socket} ->
            io:format("Client socket closed ~n")
      
    end.


server_reply({message, Msg, OtherUsername}) ->
    io:format("From: ~p~n", [OtherUsername]),
    io:format("Message: ~p~n", [Msg]);

server_reply({online, OnlineUsers}) ->
    io:format("Online Users: ~p~n", [OnlineUsers]).

client_try(Username, send, Msg, OtherUsername) ->
    Username ! {send, Msg, OtherUsername}.

client_try(Username, brodcast, Msg) ->
    Username ! {brodcast, Msg, Username}.

client_try(Username, online) ->
    Username ! online;

client_try(Username, stop) ->
    Username ! stop.
