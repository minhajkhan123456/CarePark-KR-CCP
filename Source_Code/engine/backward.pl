/*  CarePark-KR backward chaining: a meta-interpreter over rule/4 and the base facts.
    Depth-first, left-to-right SLD resolution, facts before rules, rules in source order,
    negation as failure for not/1, builtins evaluated when their inputs are bound.
    Records a Prolog box-model trace (CALL / EXIT / REDO / FAIL, plus TRY for each rule)
    and returns a proof tree. why_not/2 explains a failed goal down to the missing fact. */
:- module(backward, [quiet_solve/1, use_base/1, use_base_with_allocation/1, prove/3, prove_all/2, why_not/2,
                     trace_lines/1, print_trace/0, print_tree/1, print_why/1, b/1]).
:- use_module(core).
:- use_module(allocate).
:- use_module(library(lists)).

:- dynamic b/1, tr/4.
:- initialization((nb_setval(bw_n, 0), nb_setval(bw_quiet, false))).

use_base(Sc) :- base_facts(Sc, Fs), retractall(b(_)), forall(member(F, Fs), assertz(b(F))).
use_base_with_allocation(Sc) :-
    run_day(Sc, _), findall(assigned(V, B), alloc(V, B, _, _), As),
    use_base(Sc), forall(member(A, As), assertz(b(A))).

max_lines(6000).
% tracing is on by default; quiet_solve/1 switches it off for bulk checks
log(D, P, G) :-
    (   nb_current(bw_quiet, true) -> true
    ;   nb_getval(bw_n, N), ( max_lines(M), N >= M -> true ; fmt(G, S), assertz(tr(N, D, P, S)), N1 is N + 1, nb_setval(bw_n, N1) ) ).
reset_trace :- retractall(tr(_, _, _, _)), nb_setval(bw_n, 0), nb_setval(bw_quiet, false).
quiet_solve(G) :- nb_setval(bw_quiet, true), ( once(solve(G, 0, _)) -> R = true ; R = false ), nb_setval(bw_quiet, false), R == true.

% prove(+Goal, -Tree, -Trace): first proof
prove(G, Tree, Lines) :-
    reset_trace,
    ( once(solve(G, 0, Tree)) -> true ; Tree = none ),
    trace_lines(Lines).
prove_all(G, Answers) :- reset_trace, nb_setval(bw_quiet, true), findall(G, solve(G, 0, _), A0), sort(A0, Answers).

trace_lines(L) :- findall(D-P-S, tr(_, D, P, S), L).

solve(G, D, T) :- D > 40, !, log(D, 'FAIL', G), T = depth_limit, fail.
solve(not(A), D, node(not(A), naf, Kids)) :- !,
    log(D, 'CALL', not(A)), D1 is D + 1,
    (   once(solve(A, D1, Proof))
    ->  log(D, 'FAIL', not(A)), Kids = [Proof], fail
    ;   log(D, 'EXIT', not(A)), Kids = [] ).
solve(G, D, node(G, builtin, [])) :- is_builtin(G), !,
    log(D, 'CALL', G),
    (   eval_builtin(G) -> log(D, 'EXIT', G) ; log(D, 'FAIL', G), fail ).
solve(G, D, T) :-
    log(D, 'CALL', G),
    (   alternative(G, D, T), ( log(D, 'EXIT', G) ; log(D, 'REDO', G), fail )
    ;   log(D, 'FAIL', G), fail ).

alternative(G, _, node(G, fact, [])) :- b(G).
alternative(G, D, node(G, Id, Kids)) :-
    rule(Id, H0, B0, _), copy_term(H0-B0, G-B),
    ( nb_current(bw_quiet, true) -> true ; fmt_list(B, BS), format(atom(Try), '~w: ~w', [Id, BS]), assertz_try(D, Try) ),
    D1 is D + 1, solve_list(B, D1, Kids).
assertz_try(D, Text) :-
    (   nb_current(bw_quiet, true) -> true
    ;   nb_getval(bw_n, N), ( max_lines(M), N >= M -> true ; assertz(tr(N, D, 'TRY', Text)), N1 is N + 1, nb_setval(bw_n, N1) ) ).

solve_list([], _, []).
solve_list([L|Ls], D, [T|Ts]) :- solve(L, D, T), solve_list(Ls, D, Ts).

% ---------------------------------------------------------------- why not
% why_not(+Goal, -Explanation): none if provable; otherwise blocked(Goal, [why(Rule, Literal, Sub)...]) or missing(Goal)
why_not(G, none) :- quiet(G), !.
why_not(G, E) :- why_not(G, 0, E).
why_not(G, _, false_comparison(G)) :- is_builtin(G), !.
why_not(not(A), _, holds(A, Tree)) :- !, prove(A, Tree, _).
why_not(G, D, E) :-
    findall(Id-H0-B0, (rule(Id, H0, B0, _), \+ \+ H0 = G), Rs),
    (   Rs == [] -> E = missing(G)
    ;   D > 12 -> E = too_deep(G)
    ;   findall(why(Id, Lit, Sub), (member(Id-H0-B0, Rs), copy_term(H0-B0, G-B), first_failing(B, Lit), D1 is D + 1, why_not(Lit, D1, Sub)), Ws),
        E = blocked(G, Ws) ).
first_failing([L|Ls], F) :- ( quiet(L) -> first_failing(Ls, F) ; F = L ).
quiet(not(A)) :- !, \+ quiet(A).
quiet(G) :- is_builtin(G), !, eval_builtin(G).
quiet(G) :- b(G).
quiet(G) :- rule(_, H0, B0, _), copy_term(H0-B0, G-B), quiet_list(B).
quiet_list([]).
quiet_list([L|Ls]) :- quiet(L), quiet_list(Ls).

% ---------------------------------------------------------------- printing
print_trace :- forall(tr(_, D, P, S), (indent(D), (P == 'TRY' -> format('      try ~w~n', [S]) ; (format(atom(Pp), '~w~t~6|', [P]), format('~w~w~n', [Pp, S]))))).
indent(D) :- forall(between(1, D, _), write('|  ')).
print_tree(T) :- print_tree(T, 0).
print_tree(none, _) :- writeln('  (no proof)').
print_tree(node(G, Via, Kids), I) :- tab(I), fmt(G, S), format('~w  <~w>~n', [S, Via]), I2 is I + 2, forall(member(K, Kids), print_tree(K, I2)).
print_tree(depth_limit, I) :- tab(I), writeln('(depth limit)').
print_why(E) :- print_why(E, 1).
print_why(none, _) :- writeln('  the goal is provable').
print_why(missing(G), I) :- tab(I), fmt(G, S), format('~w   <- no such fact is stored~n', [S]).
print_why(false_comparison(G), I) :- tab(I), fmt(G, S), format('~w   <- comparison is false~n', [S]).
print_why(holds(A, _), I) :- tab(I), fmt(A, S), format('~w holds, so its negation fails~n', [S]).
print_why(too_deep(G), I) :- tab(I), fmt(G, S), format('~w (search stopped)~n', [S]).
print_why(blocked(G, Ws), I) :-
    tab(I), fmt(G, S), format('~w cannot be proved:~n', [S]),
    I2 is I + 2, forall(member(why(Id, L, Sub), Ws), (tab(I2), fmt(L, LS), format('~w blocked at ~w~n', [Id, LS]), I3 is I2 + 2, print_why(Sub, I3))).
