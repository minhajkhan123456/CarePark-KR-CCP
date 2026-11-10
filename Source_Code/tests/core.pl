:- begin_tests(builtins).
test(lt) :- core:eval_builtin(lt(1, 2)).
test(lt_false, [fail]) :- core:eval_builtin(lt(2, 2)).
test(le) :- core:eval_builtin(le(2, 2)).
test(gt) :- core:eval_builtin(gt(3, 2)).
test(ge_false, [fail]) :- core:eval_builtin(ge(2, 3)).
test(eq_binds) :- core:eval_builtin(eq(X, 5)), X == 5.
test(neq) :- core:eval_builtin(neq(a, b)).
test(neq_unbound, [fail]) :- core:eval_builtin(neq(_, b)).
test(add) :- core:eval_builtin(add(2, 3, X)), X == 5.
test(sub) :- core:eval_builtin(sub(420, 30, X)), X == 390.
test(mul) :- core:eval_builtin(mul(3, 50, X)), X == 150.
test(cdiv_rounds_up) :- core:eval_builtin(cdiv(61, 60, X)), X == 2.
test(cdiv_exact) :- core:eval_builtin(cdiv(120, 60, X)), X == 2.
test(cdiv_zero) :- core:eval_builtin(cdiv(0, 60, X)), X == 0.
test(unbound_comparison, [fail]) :- core:eval_builtin(lt(_, 3)).
:- end_tests(builtins).

:- begin_tests(knowledge_base).
test(fact_count) :- core:base_facts(none, F), length(F, N), N >= 400.
test(rule_count) :- aggregate_all(count, core:rule(_, _, _, _), 97).
test(ic_count) :- aggregate_all(count, rules:ic(_, _, _, _), 13).
test(rule_ids_unique) :- findall(I, core:rule(I, _, _, _), Is), sort(Is, S), length(Is, N), length(S, N).
test(every_rule_documented) :- forall(core:rule(I, _, _, _), rules:rule_text(I, _)).
test(no_duplicate_facts) :- core:base_facts(none, F), sort(F, S), length(F, N), length(S, N).
test(facts_ground) :- core:base_facts(none, F), forall(member(X, F), ground(X)).
test(range_restricted) :-
    forall(core:rule(I, H, B, _), ( term_variables(H, HV), exclude([L]>>(L = not(_)), B, Pos), term_variables(Pos, BV),
                                    forall(member(V, HV), (member(W, BV), V == W)) -> true ; throw(unsafe(I)) )).
test(negation_safe) :-
    forall(( core:rule(I, _, B, _), nth1(K, B, not(A)) ),
           ( length(P, K), append(P, _, B), K1 is K - 1, length(Before, K1), append(Before, _, B),
             term_variables(A, AV), term_variables(Before, BV), forall(member(V, AV), (member(W, BV), V == W)) -> true ; throw(unsafe_negation(I)) )).
test(builtins_bound_by_earlier_literals) :-
    forall(( core:rule(I, _, B, _), nth1(K, B, L), core:is_builtin(L), L \= eq(_, _), L \= add(_, _, _), L \= sub(_, _, _), L \= mul(_, _, _), L \= cdiv(_, _, _) ),
           ( K1 is K - 1, length(Before, K1), append(Before, _, B), term_variables(L, LV), term_variables(Before, BV),
             forall(member(V, LV), (member(W, BV), V == W)) -> true ; throw(unbound_builtin(I)) )).
test(stratified) :- core:strata(S), forall(member(_-N, S), N < 10).
test(three_strata) :- core:strata(S), aggregate_all(max(N), member(_-N, S), 2).
test(walk_table_complete) :- facts:departments(D), length(D, ND), forall(facts:zone(Z, _, _), (facts:walk_row(Z, M), length(M, ND))).
test(every_bay_has_zone) :- forall(facts:bay(_, Z, _), facts:zone(Z, _, _)).
test(bays) :- aggregate_all(count, facts:bay(_, _, _), 29).
test(drivers) :- aggregate_all(count, facts:driver(_, _, _, _, _, _, _, _, _), 15).
test(scenarios) :- aggregate_all(count, core:scen(_, _, _, _, _, _, _), 22).
:- end_tests(knowledge_base).
