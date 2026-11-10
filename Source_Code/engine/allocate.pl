/*  CarePark-KR control layer: replays the day event by event.
    Horn logic derives every legal bay with a cost; choosing exactly one bay per vehicle,
    keeping track of time and freeing bays when cars leave are outside Horn logic, so they live here.

    Policy: events in time order; at the same minute departures first, then arrivals by
    priority class (0 = emergency ... 5), then arrival order. Each admitted vehicle takes the
    free candidate bay with the lowest cost (walking metres + penalties), ties by bay id.
    With no free candidate it waits; every departure retries the waiting list by priority.  */
:- module(allocate, [run_day/2, run_day/3, alloc/4, decision/2, denial_reason/2, best_priority/2, day_events/1]).
:- use_module(core).
:- use_module('../kb/rules').
:- use_module(library(lists)).
:- use_module(library(pairs)).
:- use_module(library(apply)).

:- dynamic alloc/4, decision/2, busy/3, waiting/3, day_events/1.

% run_day(+Scenario, -Result) : Result = day{phase1:Log1, phase2:Log2, ...}
run_day(Sc, R) :- run_day(Sc, R, []).
run_day(Sc, R, _Opts) :-
    core:base_facts(Sc, Fs),
    findall(I, phase1_rule(I), P1),
    saturate(Fs, P1, Log1),
    simulate(Events),
    findall(assigned(V, B), alloc(V, B, _, _), As),
    findall(F, m(F), W1),
    append(W1, As, W2),
    findall(I, (rule(I, _, _, _), rules:phase2(I)), P2),
    saturate(W2, P2, Log2),
    R = day{facts:Fs, phase1:Log1, phase2:Log2, events:Events}.

best_priority(V, P) :- aggregate_all(min(X), m(priority(V, X)), P), number(P), !.
best_priority(_, 9).

arrivals(L) :- findall(T-V, m(arrival(V, T)), L0), msort(L0, L).

simulate(Events) :-
    retractall(alloc(_, _, _, _)), retractall(decision(_, _)), retractall(busy(_, _, _)), retractall(waiting(_, _, _)),
    forall(m(occupies(V, B)), ( m(since(V, S)), m(stay(V, St)) -> U is S + St, assertz(busy(B, V, U)) ; assertz(busy(B, V, 99999)) )),
    arrivals(As),
    findall(T-ord(P, I, V), (nth1(I, As, T-V), best_priority(V, P)), Keyed0), msort(Keyed0, Keyed),
    nb_setval(events, []),
    forall(member(T-ord(_, _, V), Keyed), ( release_until(T), arrive(T, V) )),
    release_until(99998),
    forall(waiting(V, _, _), (retract(waiting(V, _, _)), assertz(decision(V, unplaced)), log(1440, unplaced(V)))),
    nb_getval(events, Ev), reverse(Ev, Events),
    retractall(day_events(_)), assertz(day_events(Events)).

log(T, E) :- nb_getval(events, L), nb_setval(events, [T-E|L]).

arrive(T, V) :-
    (   \+ m(admitted(V))
    ->  denial_reason(V, Why), assertz(decision(V, denied(Why))), log(T, denied(V, Why))
    ;   place(T, V, T) -> true
    ;   best_priority(V, P), assertz(waiting(V, P, T)), log(T, wait(V)) ).

% place(+Now, +V, +ArrivedAt): take the cheapest free candidate bay now
place(Now, V, Arr) :-
    findall(C-B, (m(cost(V, B, C)), \+ busy(B, _, _)), L0),
    L0 \== [], msort(L0, [Cost-Bay|_]),
    m(stay(V, St)), Until is Now + St,
    assertz(busy(Bay, V, Until)), assertz(alloc(V, Bay, Now, Until)),
    best_priority(V, P), Wait is Now - Arr,
    assertz(decision(V, allocate(Bay, Cost, P, Wait))),
    log(Now, park(V, Bay, Cost)).

% free every bay whose stay ends at or before T, retrying the waiting list after each release
release_until(T) :-
    (   findall(U-B-V, (busy(B, V, U), U =< T), Ds), Ds \== [], msort(Ds, [U0-B0-V0|_])
    ->  retract(busy(B0, V0, U0)), log(U0, leave(V0, B0)),
        retry_waiting(U0), release_until(T)
    ;   true ).
retry_waiting(Now) :-
    findall(P-A-V, waiting(V, P, A), W0), msort(W0, W),
    forall(member(_-A-V, W), ( place(Now, V, A) -> retract(waiting(V, _, _)) ; true )).

% the first entry condition that fails, in the order the gate checks them
denial_reason(V, plate_unreadable) :- \+ m(identified(V)), !.
denial_reason(V, security_ban)     :- m(drives(P, V)), m(banned(P)), !.
denial_reason(V, badge_invalid)    :- m(drives(P, V)), m(staff_member(P)), \+ m(badge_valid(P)), !.
denial_reason(V, outside_delivery_slot) :- m(drives(P, V)), m(supplier(P)), \+ m(delivery_window(P)), !.
denial_reason(V, unregistered)     :- \+ m(drives(_, V)), !.
denial_reason(_, not_cleared).
