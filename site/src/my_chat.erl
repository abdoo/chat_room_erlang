%% -*- mode: nitrogen -*-
%% vim: ts=4 sw=4 et
-module (my_chat).
-compile(export_all).
-include_lib("nitrogen_core/include/wf.hrl").
-include("records.hrl").

main() -> #template { file="./site/templates/bare.html" }.

title() -> "Hello from Erlang Chat!".

body() -> 
    [
	#panel{id=chatwrapper, body=[
	#br{},
	#label{ text="Welcome to Erlang Chat room"},
        #h2 {text="Please Enter name of chatroom"},
        #textbox{id=chatname, text="Chatroom"},

        #button{postback=start_chat, text="Start Chat"}
    ]}
    ].
	

right_step2(Chatroom) ->
    [
	#br{},
        #span { text="Your Nick name: " }, 
        #textbox { id=userNameTextBox, text="Anonymous", style="width: 100px;", next=messageTextBox },

        #p{},
        #panel { id=chatHistory, class=chat_history, style="height: 700px;" },

        #p{},
        #textbox { id=messageTextBox, style="width: 70%; border: 5px solid black", next=sendButton },
        #button { id=sendButton, text="Send", postback={chat,Chatroom} }
    ].


event(start_chat) ->
    Chatroom = wf:q(chatname),
    wf:replace(chatwrapper, right_step2(Chatroom)),
    start_chat(Chatroom);

event({chat,Chatroom}) ->
    check_ets(),
    Username = wf:q(userNameTextBox),
    Message = wf:q(messageTextBox),
    set_color(Username), 
    wf:send_global(Chatroom, {message, Username, Message}),
    wf:wire("obj('messageTextBox').focus(); obj('messageTextBox').select();");

event({reconnect, Chatroom}) ->
    wf:insert_bottom(chatHistory, [#p{}, #span{text=["Reconnecting to ",Chatroom], class=message }]),
    start_chat(Chatroom).

start_chat(Chatroom) ->
    wf:wire(#comet{
        scope=global,
        pool=Chatroom,
        function=fun() -> start_chat_loop(Chatroom) end,
        reconnect_actions=[
            #event{postback={reconnect, Chatroom}}
        ]
    }).

start_chat_loop(Chatroom) ->
    add_message(["Connected to ",Chatroom]),
    chat_loop().

chat_loop() -> 
    receive 
        'INIT' ->
            %% The init message is sent to the first process in a comet pool.
            add_message("You are the only person in the chat room.");
        {message, Username, MsgText} ->
            add_message({Username, MsgText})
    end,
    chat_loop().

add_message({UserName, _Text} = Message) ->
    FormattedTerms = format_message(Message, get_color(UserName)),
    wf:insert_bottom(chatHistory, FormattedTerms),
    wf:wire("obj('chatHistory').scrollTop = obj('chatHistory').scrollHeight;"),
    wf:flush();
add_message(Message) ->
    FormattedTerms = format_message(Message),
    wf:insert_bottom(chatHistory, FormattedTerms),
    wf:wire("obj('chatHistory').scrollTop = obj('chatHistory').scrollHeight;"),
    wf:flush().

format_message({Username, MsgText}, Color) ->
    [
        #p{},
        #span { text=Username, class=username, style=Color}, ": ",
        #span { text=MsgText, class=message, style=Color }
    ].
format_message(MsgText) ->
    [
        #p{},
        #span { text=MsgText, class=message }
    ].

set_color(UserName)->
	set_color_help(UserName).

set_color_help(UserName) ->
	case ets:lookup(chat_color, UserName) of
		[{Key, Value}] ->
			if 
			    Key /= UserName ->
			        ets:insert(chat_color, {UserName, get_C()});
			    true ->
			        Value
			end;
		_ ->
			ets:insert(chat_color, {UserName, get_C()})
	end.
			

generate_random_no() ->
	L = [random:uniform(X) ||  X <- lists:seq(1,6)],
	generate_random_no_help(L, "").

generate_random_no_help([], Acc) ->
	Acc;
generate_random_no_help([H|T], Acc) ->
	NewAcc = Acc ++ integer_to_list(H),
	generate_random_no_help(T, NewAcc).

get_color(UserName)->
	[{_Key, Value}] = ets:lookup(chat_color, UserName),
	"color: " ++ atom_to_list(Value) ++ ";".

check_ets() ->
    case catch(ets:new(chat_color, [named_table])) of
        {'EXIT',{badarg, _Error}} ->
	    io:format("ets is already exist~n");
	chat_color ->
	   io:format("ets created~n")
    end.

get_C() ->
    lists:nth(random:uniform(10), colors()).

colors()-> [
    '#e21400', '#91580f', '#f8a700', '#f78b00',
    '#58dc00', '#287b00', '#a8f07a', '#4ae8c4',
    '#3b88eb', '#3824aa', '#a700ff', '#d300e7'
  ].
