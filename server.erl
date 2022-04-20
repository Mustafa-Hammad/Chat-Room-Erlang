-module(server).
-export([start/0, clients_list/1, client_register/1]).


start() ->
    Client_DB = subscriberETS:start(),
    ClientsTablePID = spawn(server, clients_list, [Client_DB]),
    register(clients, ClientsTablePID),
    start_listen().

start_listen() ->
    {ok, Listen} = gen_tcp:listen(8000, [binary, {reuseaddr, true},{active, true}]),
    loop_server(Listen),
    start_listen().

loop_server(Listen) ->
    {ok, Socket} = gen_tcp:accept(Listen),
    HandlerPID = spawn(server, client_register, [Socket]),
    ok = gen_tcp:controlling_process(Socket, HandlerPID),
    loop_server(Listen).

client_register(Socket) ->
    receive
        {tcp, Socket, Bin} ->
            {register,User_name} = binary_to_term(Bin),
            io:format("Registering ~p~n", [User_name]),
            clients ! {insert, User_name, Socket},
            clients ! {online, User_name},
            client_handler(Socket, User_name);

        {tcp_closed, Socket} ->
            io:format("Handler socket closed ~n")
    end.

client_handler(Socket, User_name) ->
    receive
        {tcp, Socket, Bin} ->
            ClientRequest = binary_to_term(Bin),
            client_request(ClientRequest, User_name),
            client_handler(Socket, User_name);

        {tcp_closed, Socket} ->
            io:format("Handler socket closed ~n"),
            clients ! {delete, User_name}
    end.


clients_list(Client_DB) ->
    receive
        {insert, User_name, Socket} ->
            true = subscriberETS:connect(Client_DB, User_name, Socket),
            clients_list(Client_DB);
        
        {send, Msg, User_name, OtherUser_name} ->
            OtherSocket = subscriberETS:get_socket(Client_DB, OtherUser_name),
            ok = gen_tcp:send(OtherSocket, term_to_binary({message, Msg, User_name})),
            clients_list(Client_DB);

        {brodcast, Msg, User_name} ->
            All_Sockets = subscriberETS:get_all_sockets(Client_DB),
            List_of_sockets = lists:append(All_Sockets),
            brodcast_message(List_of_sockets, Msg, User_name),
            clients_list(Client_DB);
        
        {delete, User_name} ->
            subscriberETS:disconnect(Client_DB, User_name),
            clients_list(Client_DB);

        {online, User_name} ->
            UserSocket = subscriberETS:get_socket(Client_DB, User_name),
            AllOnlineUsers = subscriberETS:get_online_users(Client_DB),
            OtherOnlineUsers = lists:delete([User_name], AllOnlineUsers),
            ok = gen_tcp:send(UserSocket, term_to_binary({online, OtherOnlineUsers})),
            clients_list(Client_DB)
    end.


brodcast_message([H|T], Msg, User_name) ->
    ok = gen_tcp:send(H, term_to_binary({message, Msg, User_name})),
    brodcast_message(T, Msg, User_name);

brodcast_message([], _, _) ->
    done.

client_request({send, Msg, OtherUser_name}, User_name) ->
    io:format("From: ~p ~n", [User_name]),
    io:format("To: ~p~n", [OtherUser_name]),
    io:format("Sending: ~p~n", [Msg]),
    clients ! {send, Msg, User_name, OtherUser_name};

client_request({brodcast, Msg, User_name}, User_name) ->
    io:format("From ~p~n", [User_name]),
    io:format("brodcast message ~p~n", [Msg]),
    clients ! {brodcast, Msg, User_name};

client_request(online, User_name) ->
    clients ! {online, User_name}.


