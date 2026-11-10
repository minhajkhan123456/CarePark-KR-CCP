/*  CarePark-KR: integrity constraints and scenario checking. */
:- module(check, [violations/1, outcome_map/1, expected_map/2, check_scenario/3, scenario_report/2]).
:- use_module(core).
:- use_module(allocate).
:- use_module('../kb/rules').
:- use_module('../kb/scenarios').
:- use_module(library(lists)).
:- use_module(library(pairs)).

% violations(-List): every integrity constraint that fails on the current model + allocation
violations(L) :- findall(Id-W, (rules:ic(Id, _, _, G), copy_term(G, G1), call(check:G1), witness(G1, W)), L0), sort(L0, L).
witness(G, W) :- term_variables(G, _), format(atom(W), '~q', [G]).

outcome_map(Map) :-
    findall(V-O, (decision(V, D), outcome(D, O)), M0), sort(M0, Map).
outcome(allocate(B, _, _, _), B).
outcome(denied(R), denied(R)).
outcome(unplaced, unplaced).

expected_map(Sc, Map) :-
    scenarios:baseline_outcomes(Base), core:scen(Sc, _, _, _, _, Changes, _),
    foldl([V-O, A0, A]>>( (selectchk(V-_, A0, A1) -> true ; A1 = A0), A = [V-O|A1] ), Changes, Base, M0),
    sort(M0, Map).

% check_scenario(+Sc, -Pass, -Problems)
check_scenario(Sc, Pass, Problems) :-
    run_day(Sc, _),
    outcome_map(Got), expected_map(Sc, Want),
    ( Got == Want -> P1 = [] ; subtract(Got, Want, Extra), subtract(Want, Got, Missing), P1 = [got(Extra), wanted(Missing)] ),
    core:scen(Sc, _, _, _, _, _, Checks),
    violations(Vs), pairs_keys(Vs, VIds0), sort(VIds0, VIds),
    findall(C, (member(C, Checks), \+ check_ok(C, VIds)), P2),
    append(P1, P2, Problems),
    ( Problems == [] -> Pass = pass ; Pass = fail ).

check_ok(alert(A), _) :- m(A).
check_ok(ic(Id), VIds) :- memberchk(Id, VIds).
check_ok(no_ic, VIds) :- VIds == [].
check_ok(wait(V, W), _) :- decision(V, allocate(_, _, _, W)).

scenario_report(Sc, R) :- check_scenario(Sc, P, Pr), R = Sc-P-Pr.
