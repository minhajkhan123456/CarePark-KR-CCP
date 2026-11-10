/*  CarePark-KR: size of every representation, counted from the code. */
:- module(stats, [stats/1]).
:- use_module(core).
:- use_module(allocate).
:- use_module(frames).
:- use_module(semnet).
:- use_module(fol).
:- use_module(dl).
:- use_module('../kb/rules').
:- use_module('../kb/facts', []).
:- use_module(library(lists)).

stats(S) :-
    base_facts(none, Fs), length(Fs, NF),
    aggregate_all(count, rule(_, _, _, _), NR), aggregate_all(count, (rule(I, _, _, _), \+ rules:phase2(I)), NR1), NR2 is NR - NR1,
    aggregate_all(count, rules:ic(_, _, _, _), NIC),
    run_day(none, R), length(R.phase1, D1), length(R.phase2, D2), DT is D1 + D2,
    aggregate_all(max(C), member(fire(C, _, _, _, _), R.phase1), C1),
    aggregate_all(max(C), member(fire(C, _, _, _, _), R.phase2), C2), CT is C1 + C2,
    strata(St), aggregate_all(max(N), member(_-N, St), MaxS), NS is MaxS + 1,
    aggregate_all(count, m(_), WM),
    aggregate_all(count, facts:driver(_, _, _, _, _, _, _, _, _), ND), aggregate_all(count, facts:parked(_, _, _, _, _, _, _, _, _), NP),
    aggregate_all(count, facts:bay(_, _, _), NB), aggregate_all(count, facts:zone(_, _, _), NZ), aggregate_all(count, facts:level(_, _, _), NL),
    facts:departments(Dp), length(Dp, NDp),
    aggregate_all(count, core:scen(_, _, _, _, _, _, _), NSc),
    class_frames(CF), length(CF, NCF), instance_frames(IF), length(IF, NIF), aggregate_all(count, scene(_, _, _, _, _), NSn),
    nodes(Nn), length(Nn, NN), aggregate_all(count, link(_, _, _), NLk),
    aggregate_all(count, fol(_, _, _, _, _, _), NFol), aggregate_all(count, fol(_, _, _, _, not_horn, _), NFolN),
    tbox_size(NT), inferred(Inf), length(Inf, NInf),
    aggregate_all(count, allocate:decision(_, allocate(_, _, _, _)), NPark),
    aggregate_all(count, allocate:decision(_, denied(_)), NDen),
    S = ['Ground facts'-NF, 'Horn rules'-NR, 'Phase-1 rules (decision)'-NR1, 'Phase-2 rules (monitoring)'-NR2,
         'Integrity constraints'-NIC, 'Negation strata'-NS, 'Derived facts (both phases)'-DT, 'Inference cycles, phase 1'-C1, 'Inference cycles, both phases'-CT,
         'Working memory at the fixed point'-WM, 'Drivers arriving'-ND, 'Vehicles parked overnight'-NP, 'Bays'-NB, 'Zones'-NZ,
         'Levels'-NL, 'Departments'-NDp, 'Vehicles parked (baseline day)'-NPark, 'Vehicles denied (baseline day)'-NDen,
         'Test scenarios'-NSc, 'Class frames'-NCF, 'Instance frames'-NIF, 'Script scenes'-NSn, 'Semantic network nodes'-NN,
         'Semantic network links'-NLk, 'FOL statements'-NFol, 'FOL statements beyond Horn'-NFolN, 'DL TBox axioms'-NT,
         'Inferred subsumptions'-NInf].
