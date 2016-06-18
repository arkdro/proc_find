-module(proc_find).

-export([
         start/0,
         start/1,
         loop/1,
         one_iter/0
        ]).

start() ->
    start(delay()).

start(Delay) ->
    Args = [Delay],
    spawn(?MODULE, loop, Args).

loop(Delay) ->
    one_iter(),
    timer:sleep(Delay),
    ?MODULE:loop(Delay).

one_iter() ->
    Procs = get_processes(),
    Data = get_queue_data(Procs),
    Stat = calc_stat(Data),
    write_stat(Stat).

delay() ->
    1000.

get_processes() ->
    [Pid || Pid <- processes(), is_p1_fsm(Pid)].

is_p1_fsm(Pid) ->
    case process_info(Pid, dictionary) of
        undefined ->
            false;
        {dictionary, Props} ->
            proplists:is_defined('$internal_queue_len', Props)
    end.

get_queue_data(Procs) ->
    [{Pid, get_one_queue_data(Pid)} || Pid <- Procs].

get_one_queue_data(Pid) ->
    get_queue_len_one_process(Pid)
        + get_internal_queue_len_one_process(Pid).

get_queue_len_one_process(Pid) ->
    case process_info(Pid, message_queue_len) of
        {message_queue_len, N} ->
            N;
        undefined ->
            0
    end.

get_internal_queue_len_one_process(Pid) ->
    case process_info(Pid, dictionary) of
        undefined ->
            0;
        {dictionary, Props} ->
            case proplists:get_value('$internal_queue_len', Props) of
                N when is_integer(N) ->
                    N;
                _ ->
                    0
            end
    end.

calc_stat([]) ->
    [];
calc_stat(Data) ->
    L2 = [{N, Pid} || {Pid, N} <- Data],
    {Max3, Max, Min, Sum} = get_max_min(L2),
    Len = length(Data),
    Avg = Sum / Len,
    [
     {length, Len},
     {max3, Max3},
     {max, Max},
     {min, Min},
     {sum, Sum},
     {avg, Avg}
    ].

get_max_min(L) ->
    get_max_min(L, [], {-1, stub}, {1000000, stub}, 0).

get_max_min([], Max3, Max, Min, Sum) ->
    {Max3, Max, Min, Sum};
get_max_min([H | T], Max3, Max, Min, Sum) ->
    NewMax3 = choose_max3(H, Max3),
    Max2 = choose_max(H, Max),
    Min2 = choose_min(H, Min),
    Sum2 = calc_new_sum(H, Sum),
    get_max_min(T, NewMax3, Max2, Min2, Sum2).

calc_new_sum({N, _}, Sum) ->
    N + Sum.

choose_max3(Item, L) ->
    L2 = lists:sort(fun erlang:'>'/2, [Item | L]),
    lists:sublist(L2, 3).

choose_max(H, Max) when H > Max ->
    H;
choose_max(_, Max) ->
    Max.

choose_min(H, Min) when H < Min ->
    H;
choose_min(_, Min) ->
    Min.

write_stat(Stat) ->
    lager:info("proc_find, stat: ~p", [Stat]).
