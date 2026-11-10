/*  CarePark-KR command line.
      swipl main.pl                       interactive menu
      swipl main.pl day [Scenario]        replay the day: decisions, events, alerts, fees
      swipl main.pl saturate [Scenario]   forward chaining trace, cycle by cycle
      swipl main.pl prove "Goal"          backward chaining with the box-model trace and proof tree
      swipl main.pl whynot "Goal"         why a goal cannot be proved
      swipl main.pl scenarios             run the 22 test scenarios
      swipl main.pl frames | net | fol | dl | script | rules | facts | stats | export      */
:- encoding(utf8).
:- use_module(engine/core).
:- use_module(engine/allocate).
:- use_module(engine/check).
:- use_module(engine/backward).
:- use_module(engine/fol).
:- use_module(engine/dl).
:- use_module(engine/frames).
:- use_module(engine/semnet).
:- use_module(engine/stats).
:- use_module(kb/rules).
:- use_module(library(lists)).

:- initialization(main, main).

main(Argv) :- set_stream(user_output, encoding(utf8)), ( Argv == [] -> menu ; run(Argv) ).
main :- current_prolog_flag(argv, A), main(A).

bar :- format('~`=t~78|~n').
head(T) :- nl, bar, ( is_list(T) -> atomic_list_concat(T, A) ; A = T ), format('~w~n', [A]), bar.
hhmm(T, S) :- H is T // 60, M is T mod 60, format(atom(S), '~|~`0t~d~2+:~|~`0t~d~2+', [H, M]).
sc_arg([], none) :- !.
sc_arg([S|_], A) :- atom_string(A, S).

run([day|R])       :- sc_arg(R, S), day(S).
run([saturate|R])  :- sc_arg(R, S), saturate_cmd(S).
run([prove, G|R])  :- sc_arg(R, S), prove_cmd(G, S).
run([whynot, G|R]) :- sc_arg(R, S), whynot_cmd(G, S).
run([scenarios])   :- scenarios_cmd.
run([frames])      :- frames_cmd.
run([net])         :- net_cmd.
run([fol])         :- fol_cmd.
run([dl|R])        :- sc_arg(R, S), dl_cmd(S).
run([script])      :- script_cmd.
run([rules])       :- rules_cmd.
run([facts])       :- facts_cmd.
run([stats])       :- stats_cmd.
run([export])      :- shell('swipl tools/export.pl').
run(X) :- format('unknown command ~w~n', [X]), halt(1).

title(none, 'Baseline day') :- !.
title(S, T) :- core:scen(S, T, _, _, _, _, _).

day(S) :-
    title(S, T), head(T), run_day(S, R),
    length(R.facts, NF), length(R.phase1, N1), length(R.phase2, N2),
    format('~w facts in, ~w derived in phase 1 (decisions), ~w in phase 2 (monitoring)~n~n', [NF, N1, N2]),
    format('Timeline~n'),
    forall(member(Tm-E, R.events), (hhmm(Tm, H), event_text(E, Tx), format('  ~w  ~w~n', [H, Tx]))),
    format('~nDecisions~n'),
    findall(A-V, m(arrival(V, A)), L0), msort(L0, L),
    forall(member(A-V, L), (hhmm(A, H), decision(V, D), dec_text(V, D, Tx), format('  ~w  ~w~t~22|~w~n', [H, V, Tx]))),
    format('~nAlerts and guidance (phase 2)~n'),
    forall((member(P, [ambulance_bay_blocked(_), tow_request(_), charger_hog(_, _), dropoff_overstay(_), manual_check(_), security_alert(_),
                       notify_ward(_, _), alert_trauma_team(_), height_warning(_)]), m(P)), format('  ~q~n', [P])),
    format('~nFees (PKR)~n'), forall((m(fee(V, F)), alloc(V, _, _, _)), format('  ~w~t~12|~w~n', [V, F])),
    violations(Vs), format('~nIntegrity constraints IC1-IC13: ~w~n', [Vs]).

event_text(park(V, B, C), T) :- format(atom(T), '~w parks in ~w (cost ~w m)', [V, B, C]).
event_text(leave(V, B), T) :- format(atom(T), '~w leaves ~w', [V, B]).
event_text(denied(V, R), T) :- format(atom(T), '~w denied: ~w', [V, R]).
event_text(wait(V), T) :- format(atom(T), '~w waits: no free bay it may use', [V]).
event_text(unplaced(V), T) :- format(atom(T), '~w never placed', [V]).
dec_text(_, allocate(B, C, P, W), T) :- format(atom(T), 'bay ~w, cost ~w m, priority ~w, waited ~w min', [B, C, P, W]).
dec_text(_, denied(R), T) :- format(atom(T), 'DENIED (~w)', [R]).
dec_text(_, unplaced, 'never placed').

saturate_cmd(S) :-
    title(S, T), head(['Forward chaining: ', T]), run_day(S, R),
    length(R.facts, NF), format('Initial working memory: ~w facts~n', [NF]),
    strata(St), format('Strata: ~w~n', [St]),
    print_log('Phase 1', R.phase1), print_log('Phase 2', R.phase2).
print_log(Name, Log) :-
    format('~n~w~n', [Name]),
    forall(member(fire(C, St, Id, H, Bs), Log), (fmt(H, HS), format('  [c~w s~w] ~w~t~16|~w  ~w~n', [C, St, Id, HS, Bs]))),
    length(Log, N), format('  ~w new facts~n', [N]).

prove_cmd(G, S) :-
    term_string(T, G), head(['Backward chaining: ', G]),
    ( phase2_goal(T) -> use_base_with_allocation(S) ; use_base(S) ),
    prove(T, Tree, _), print_trace,
    ( Tree == none -> format('~nRESULT: not provable (negation as failure). Try whynot.~n') ; format('~nRESULT: proved ~q~n~nProof tree~n', [T]), print_tree(Tree) ).
whynot_cmd(G, S) :-
    term_string(T, G), format(atom(Hd), 'Why not: ~w', [G]), head(Hd),
    ( phase2_goal(T) -> use_base_with_allocation(S) ; use_base(S) ),
    why_not(T, E), print_why(E).
phase2_goal(T) :- functor(T, F, N), rule(Id, H, _, _), functor(H, F, N), rules:phase2(Id), !.

scenarios_cmd :-
    head('Test scenarios'),
    findall(P, (core:scen(S, T, _, _, _, _, _), check_scenario(S, P, Pr), format('  ~w ~w~t~62|~w ~w~n', [S, T, P, Pr])), Ps),
    include(==(pass), Ps, Ok), length(Ok, N), length(Ps, M), format('~n~w/~w scenarios pass~n', [N, M]).

frames_cmd :-
    head('Frames (local value -> if-needed -> inherited -> default)'), reset_frames,
    class_frames(C), instance_frames(I), length(C, NC), length(I, NI), format('~w class frames, ~w instance frames~n', [NC, NI]),
    forall(member(F, [noor, rukhsana, bushra, ev_sa, wv_no, amb1]), (
        isa_chain(F, Ch), format('~n~w   is-a: ~w~n', [F, Ch]), slots_of(F, Ss),
        forall((member(Sl, Ss), get(F, Sl, V, H)), format('    ~w~t~22|= ~w~t~52|(~w)~n', [Sl, V, H])))),
    put(ev_sa, occupies, ev1), demon_log(D), format('~nput(ev_sa, occupies, ev1) fired the if-added demon: ~w~n', [D]).

net_cmd :-
    head('Semantic network'), nodes(N), length(N, NN), aggregate_all(count, link(_, _, _), NL), relation_kinds(K),
    format('~w nodes, ~w links: ~w~n~n', [NN, NL, K]),
    forall(link(A, R, B), format('  ~w --~w--> ~w~n', [A, R, B])),
    classes_of(ev_sa, C), format('~nclasses_of(ev_sa) = ~w~n', [C]),
    inherited_parts(ev_sa, P), format('inherited parts of ev_sa = ~w~n', [P]),
    part_of_chain(amb1, PC), format('part-of chain of amb1 = ~w~n', [PC]),
    path(noor, oncology, Pa), format('path noor ~~> oncology = ~w~n', [Pa]).

fol_cmd :-
    head('First-order logic'),
    forall(fol(I, E, F, Ru, H, _), format('  ~w~t~6|~w~n        ~w  [~w, ~w]~n', [I, F, E, Ru, H])),
    run_day(none, _), check_all(L), format('~nModel checks of the statements beyond Horn clauses (baseline day)~n'),
    forall(member(I-R, L), format('  ~w ~w~n', [I, R])).

dl_cmd(S) :-
    head('Description logic'), tbox_size(N), format('TBox: ~w axioms~n', [N]),
    forall(sub(A, B), format('  ~w ⊑ ~w~n', [A, B])), forall(disj(A, B), format('  ~w ⊓ ~w ⊑ ⊥~n', [A, B])), forall(def(D), format('  ~w~n', [D])),
    inferred(I), format('~nInferred by transitivity: ~w~n', [I]),
    run_day(S, _), format('~nRealisation (most specific concepts)~n'),
    forall(member(X, [saad, noor, rukhsana, waqar, bushra, ev_sa, wv_no, amb_fa, car_ya, amb1, ev2, z_patient]),
           (most_specific(X, Cs), format('  ~w~t~12|~w~n', [X, Cs]))),
    consistency(C), ( C == [] -> format('~nABox consistent~n') ; format('~nABox INCONSISTENT: ~w~n', [C]) ).

script_cmd :- head('Script'), script(N), format('~w~n', [N]), forall(scene(I, Nm, Ac, Wh, Ru), format('  ~w. ~w (~w): ~w  ~w~n', [I, Nm, Ac, Wh, Ru])).
rules_cmd :- head('Horn rules'), strata(_), forall(rule(Id, H, B, VN), (stratum(Id, S), maplist([N=V]>>(V = '$VAR'(N)), VN), numbervars(H-B, 0, _, [singletons(true)]), fmt(H, HS), fmt_list(B, BS), rules:rule_text(Id, T), format('  ~w~t~6|[s~w] ~w :- ~w.~n        % ~w~n', [Id, S, HS, BS, T]))),
             format('~nIntegrity constraints~n'), forall(rules:ic(I, T, C, _), format('  ~w ~w~n      ~w~n', [I, C, T])).
facts_cmd :- head('Ground facts'), base_facts(none, Fs), length(Fs, N), format('~w facts~n', [N]), forall(member(F, Fs), format('  ~q.~n', [F])).
stats_cmd :- head('CarePark-KR in numbers'), stats(S), forall(member(K-V, S), format('  ~w~t~44|~w~n', [K, V])).

menu :-
    format('~nCarePark-KR  -  choose~n  1 day   2 saturate   3 prove   4 whynot   5 scenarios   6 frames~n  7 net   8 fol   9 dl   10 script   11 rules   12 stats   0 quit~n> '),
    read_line_to_string(user_input, L), ( L == end_of_file -> true ; menu_pick(L) ).
menu_pick("0") :- !.
menu_pick(L) :- number_string(N, L), nth1(N, [day, saturate, prove, whynot, scenarios, frames, net, fol, dl, script, rules, stats], C), !,
    ( memberchk(C, [prove, whynot]) -> format('goal, e.g. admitted(car_bu): '), read_line_to_string(user_input, G), run([C, G]) ; run([C]) ), menu.
menu_pick(_) :- menu.
