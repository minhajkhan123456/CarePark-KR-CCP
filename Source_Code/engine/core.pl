/*  CarePark-KR engine core: rule loading (with variable names), scenarios,
    builtins, stratification and stratified forward chaining with a full trace. */
:- module(core, [rule/4, base_facts/2, scenario_facts/3, scenario/1, scen/7,
                 eval_builtin/1, is_builtin/1, strata/1, stratum/2,
                 saturate/3, m/1, set_model/1, pred_key/2, phase1_rule/1,
                 lit_pred/2, fmt/2, fmt_list/2]).
:- use_module('../kb/facts').
:- use_module('../kb/rules').
:- use_module('../kb/scenarios').
:- use_module(library(lists)).
:- use_module(library(apply)).

:- dynamic rule/4, m/1, stratum_of/2.

% ---------------------------------------------------------------- load rules with variable names
load_rules :-
    retractall(rule(_, _, _, _)),
    module_property(rules, file(File)),
    setup_call_cleanup(open(File, read, S), read_rules(S), close(S)).
read_rules(S) :-
    read_term(S, T, [variable_names(Vs)]),
    (   T == end_of_file -> true
    ;   ( T = r(Id, H, B) -> assertz(rule(Id, H, B, Vs)) ; true ),
        read_rules(S)
    ).
:- initialization(load_rules).

% ---------------------------------------------------------------- facts and scenarios
base_facts(none, Fs) :- !, findall(F, fact(F), Fs0), list_to_set(Fs0, Fs).
base_facts(Id, Fs) :- scenario_facts(Id, Fs, _).

scen(Id, T, S, R, A, E, C) :- scenarios:sc(Id, T, S, R, A, E, C).
scenario(Id) :- scen(Id, _, _, _, _, _, _).
scenario_facts(Id, Fs, Arrivals) :-
    scen(Id, _, _, Remove, Add, _, _),
    base_facts(none, F0),
    subtract(F0, Remove, F1),
    append(F1, Add, F2), list_to_set(F2, Fs),
    findall(T-V, member(arrival(V, T), Fs), A0), msort(A0, A1), pairs_values(A1, Arrivals).

% ---------------------------------------------------------------- builtins
is_builtin(G) :- compound(G), functor(G, F, _), builtin(F).
eval_builtin(lt(X, Y))  :- number(X), number(Y), X < Y.
eval_builtin(le(X, Y))  :- number(X), number(Y), X =< Y.
eval_builtin(gt(X, Y))  :- number(X), number(Y), X > Y.
eval_builtin(ge(X, Y))  :- number(X), number(Y), X >= Y.
eval_builtin(eq(X, Y))  :- X = Y.
eval_builtin(neq(X, Y)) :- ground(X-Y), X \== Y.
eval_builtin(add(X, Y, Z)) :- number(X), number(Y), Z is X + Y.
eval_builtin(sub(X, Y, Z)) :- number(X), number(Y), Z is X - Y.
eval_builtin(mul(X, Y, Z)) :- number(X), number(Y), Z is X * Y.
eval_builtin(cdiv(X, Y, Z)) :- number(X), number(Y), Y > 0, Z is max(0, (X + Y - 1) // Y).

% ---------------------------------------------------------------- stratification
pred_key(A, F/N) :- functor(A, F, N).
lit_pred(not(A), neg(K)) :- !, pred_key(A, K).
lit_pred(A, pos(K)) :- pred_key(A, K).

phase1_rule(Id) :- rule(Id, _, _, _), \+ phase2(Id).

strata(S) :-
    retractall(stratum_of(_, _)),
    findall(K, (rule(_, H, _, _), pred_key(H, K)), Ks0), sort(Ks0, Ks),
    forall(member(K, Ks), assertz(stratum_of(K, 0))),
    relax, findall(K-N, stratum_of(K, N), S).
relax :-
    (   rule(_, H, B, _), pred_key(H, KH), stratum_of(KH, NH),
        member(L, B), \+ is_builtin(L), lit_pred(L, D),
        ( D = pos(KB), (stratum_of(KB, NB) -> true ; NB = 0), NB > NH, New = NB
        ; D = neg(KB), (stratum_of(KB, NB) -> true ; NB = 0), NB + 1 > NH, New is NB + 1 ),
        New < 50
    ->  retract(stratum_of(KH, NH)), assertz(stratum_of(KH, New)), relax
    ;   true ).
stratum(Id, N) :- rule(Id, H, _, _), pred_key(H, K), stratum_of(K, N).

% ---------------------------------------------------------------- forward chaining
% saturate(+Facts, +RuleIds, -Log): fills m/1; Log = list of fire(Cycle, Stratum, Rule, Fact, Bindings)
set_model(Fs) :- retractall(m(_)), forall(member(F, Fs), assertz(m(F))).

saturate(Fs, Ids, Log) :-
    set_model(Fs), strata(_),
    findall(N, (member(Id, Ids), stratum(Id, N)), Ns0), sort(Ns0, Ns),
    nb_setval(cycle, 0),
    foldl(run_stratum(Ids), Ns, [], RevLog),
    reverse(RevLog, Log).

run_stratum(Ids, N, Acc0, Acc) :-
    findall(Id, (member(Id, Ids), stratum(Id, N)), SIds),
    cycle_loop(SIds, N, Acc0, Acc).

cycle_loop(SIds, N, Acc0, Acc) :-
    nb_getval(cycle, C0), C is C0 + 1,
    findall(fire(C, N, Id, H, Bs),
            ( member(Id, SIds), rule(Id, H0, B0, Vs0),
              copy_term(H0-B0-Vs0, H-B-Vs),
              match(B), ground(H), \+ m(H), bindings(Vs, Bs) ),
            Fires0),
    dedup(Fires0, [], Fires),
    (   Fires == []
    ->  Acc = Acc0
    ;   nb_setval(cycle, C),
        forall(member(fire(_, _, _, H, _), Fires), assertz(m(H))),
        reverse(Fires, RF), append(RF, Acc0, Acc1),
        cycle_loop(SIds, N, Acc1, Acc) ).

dedup([], _, []).
dedup([F|Fs], Seen, Out) :-
    F = fire(_, _, _, H, _),
    (   memberchk(H, Seen) -> Out = Rest ; Out = [F|Rest] ),
    dedup(Fs, [H|Seen], Rest).

match([]).
match([L|Ls]) :- lit(L), match(Ls).
lit(not(A)) :- !, \+ m(A).
lit(A) :- is_builtin(A), !, eval_builtin(A).
lit(A) :- m(A).

bindings(Vs, Bs) :- findall(N=V, (member(N=V, Vs), N \== '_', \+ sub_atom(N, 0, 1, _, '_')), Bs).

% ---------------------------------------------------------------- printing
fmt(not(A), S) :- !, fmt(A, S0), format(atom(S), 'not ~w', [S0]).
fmt(A, S) :- format(atom(S), '~W', [A, [quoted(true), numbervars(true)]]).
fmt_list(L, S) :- maplist(fmt, L, Ss), atomic_list_concat(Ss, ', ', S).
