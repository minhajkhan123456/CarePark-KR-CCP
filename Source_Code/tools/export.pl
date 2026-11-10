:- encoding(utf8).
/*  Export the knowledge base, scenarios, Prolog results and representation data as JSON
    for the website and the JavaScript tests.   swipl tools/export.pl                       */
:- use_module('../engine/core').
:- use_module('../engine/allocate').
:- use_module('../engine/check').
:- use_module('../engine/backward').
:- use_module('../engine/fol').
:- use_module('../engine/dl').
:- use_module('../engine/frames').
:- use_module('../engine/semnet').
:- use_module('../engine/stats').
:- use_module('../kb/rules').
:- use_module('../kb/scenarios').
:- use_module('../kb/facts', []).
:- use_module(library(http/json)).
:- use_module(library(lists)).
:- use_module(library(apply)).

% term -> JSON: atoms become strings, numbers stay numbers, compound -> [functor, args...]
j(T, T) :- number(T), !.
j(T, S) :- atom(T), !, atom_string(T, S).
j(T, S) :- string(T), !, S = T.
j(not(A), ["not", JA]) :- !, jatom(A, JA).
j(T, [F|Args]) :- compound(T), T =.. [F0|As], atom_string(F0, F), maplist(j, As, Args).
jatom(A, J) :- ( atom(A), \+ A == [] -> j(A, J0), ( string(J0) -> J = [J0] ; J = J0 ) ; j(A, J) ).

alert_pattern(A) :- member(A, [ambulance_bay_blocked(_), tow_request(_), charger_hog(_, _), dropoff_overstay(_), manual_check(_),
                            security_alert(_), notify_ward(_, _), alert_trauma_team(_), height_warning(_), route(_, _, _)]).

rule_json(Id, json([id=SId, head=JH, body=JB, text=Txt, group=G, phase=Ph])) :-
    rule(Id, H, B, Vs), copy_term(H-B-Vs, H1-B1-Vs1),
    bind_names(Vs1), term_variables(H1-B1, Rest), anon(Rest, 1),
    atom_string(Id, SId), jatom(H1, JH), maplist(jatom, B1, JB),
    rules:rule_text(Id, T), atom_string(T, Txt),
    sub_atom(Id, 0, 1, _, G0), rules:rule_group(G0, GT), atom_string(GT, G),
    ( rules:phase2(Id) -> Ph = 2 ; Ph = 1 ).
bind_names([]).
bind_names([N=V|T]) :- ( var(V) -> V = N ; true ), bind_names(T).
anon([], _).
anon([V|Vs], I) :- format(atom(V), '_G~w', [I]), I1 is I + 1, anon(Vs, I1).

write_json(File, Term) :- setup_call_cleanup(open(File, write, S, [encoding(utf8)]), json_write(S, Term, [width(0)]), close(S)).

kb_json(json([facts=JF, rules=JR, constraints=JC, builtins=["lt","le","gt","ge","eq","neq","add","sub","mul","cdiv"]])) :-
    base_facts(none, Fs), maplist(jatom, Fs, JF),
    findall(J, (rule(Id, _, _, _), rule_json(Id, J)), JR),
    findall(json([id=I, text=T, clause=C]), (rules:ic(I0, T0, C0, _), atom_string(I0, I), atom_string(T0, T), atom_string(C0, C)), JC).

result_json(Sc, json([id=SId, title=T, story=St, remove=JRm, add=JAd, expected=JE, got=JG, pass=P, problems=JPr,
                      events=JEv, alerts=JAl, violations=JV, fees=JFe, decisions=JD, n1=N1, n2=N2, cycles=Cy, dl=JDl, fol=JFo])) :-
    core:scen(Sc, T0, St0, Rm, Ad, _, _), atom_string(T0, T), atom_string(St0, St), atom_string(Sc, SId),
    maplist(jatom, Rm, JRm), maplist(jatom, Ad, JAd),
    run_day(Sc, Day), length(Day.phase1, N1), length(Day.phase2, N2),
    aggregate_all(max(C1), member(fire(C1, _, _, _, _), Day.phase1), Cy1), aggregate_all(max(C2), member(fire(C2, _, _, _, _), Day.phase2), Cy2), Cy is Cy1 + Cy2,
    consistency(Cl), maplist([X, Y]>>(format(string(Y), '~q', [X])), Cl, JDl),
    check_all(FC), maplist([I-R, [SI, SR]]>>(atom_string(I, SI), atom_string(R, SR)), FC, JFo),
    check_scenario(Sc, P0, Pr), atom_string(P0, P), maplist([X, Y]>>(format(string(Y), '~q', [X])), Pr, JPr),
    outcome_map(Got), expected_map(Sc, Want),
    maplist([V-O, json([vehicle=SV, outcome=SO])]>>(atom_string(V, SV), format(string(SO), '~q', [O])), Got, JG),
    maplist([V-O, json([vehicle=SV, outcome=SO])]>>(atom_string(V, SV), format(string(SO), '~q', [O])), Want, JE),
    day_events(Ev), maplist([Tm-E, json([t=Tm, e=JEe])]>>jatom(E, JEe), Ev, JEv),
    findall(JA, (alert_pattern(A), m(A), jatom(A, JA)), JAl),
    violations(Vs), maplist([I-W, json([ic=SI, witness=SW])]>>(atom_string(I, SI), atom_string(W, SW)), Vs, JV),
    findall([SV, F], (m(fee(V, F)), atom_string(V, SV)), JFe0), sort(JFe0, JFe),
    findall(json([vehicle=SV, decision=JDd]), (decision(V, D), atom_string(V, SV), jatom(D, JDd)), JD).

frame_json(F, json([name=SF, kind=K, chain=JC, rows=Rows])) :-
    frame(F, K0, _, _), atom_string(F, SF), atom_string(K0, K), isa_chain(F, C), maplist(j, C, JC),
    slots_of(F, Ss),
    findall([SS, SV, SH, SFac, SOwn], (member(S, Ss), atom_string(S, SS),
              ( get(F, S, V, H) -> format(string(SV), '~w', [V]), atom_string(H, SH) ; SV = null, SH = "" ),
              isa_chain(F, Ch), once((member(Own, Ch), frame(Own, _, _, Sl), memberchk(S-Fac, Sl))), atom_string(Own, SOwn),
              maplist([X, Y]>>(format(string(Y), '~w', [X])), Fac, FacS), atomic_list_concat(FacS, ' · ', SFa), atom_string(SFa, SFac)), Rows).

site_json(json([frames=JF, links=JL, fol=JFol, tbox=JT, script=JS, stats=JSt, walk=JW, departments=JDp, building=JB, people=JP])) :-
    reset_frames, findall(J, (frame(F, _, _, _), F \== 'Thing', frame_json(F, J)), JF),
    findall([SA, SR, SB], (link(A, R, B), atom_string(A, SA), atom_string(R, SR), atom_string(B, SB)), JL),
    run_day(none, _), check_all(Checks),
    findall(json([id=SI, english=SE, formula=SFo, runs=SRu, horn=H, check=SC]),
            (fol(I, E, Fo, Ru, H0, _), atom_string(I, SI), atom_string(E, SE), atom_string(Fo, SFo), atom_string(Ru, SRu),
             ( H0 == horn -> H = true ; H = false ), ( memberchk(I-C, Checks) -> atom_string(C, SC) ; SC = "" )), JFol),
    findall(S, (sub(A, B), format(string(S), '~w ⊑ ~w', [A, B])), Subs),
    findall(S, (disj(A, B), format(string(S), '~w ⊓ ~w ⊑ ⊥', [A, B])), Dis),
    findall(S, (def(D), atom_string(D, S)), Defs),
    inferred(Inf), findall(S, (member(A-B, Inf), format(string(S), '~w ⊑ ~w', [A, B])), JInf),
    JT = json([subsumption=Subs, disjoint=Dis, definitions=Defs, inferred=JInf]),
    script(SN), findall(json([n=N, name=Nm, actor=Ac, what=Wh, rules=JRu]), (scene(N, Nm0, Ac0, Wh0, Ru), atom_string(Nm0, Nm), atom_string(Ac0, Ac), atom_string(Wh0, Wh), maplist(j, Ru, JRu)), Sc),
    atom_string(SN, SSN), JS = json([name=SSN, scenes=Sc]),
    stats(St), maplist([K-V, [SK, V]]>>atom_string(K, SK), St, JSt),
    findall([SZ|Ms], (facts:walk_row(Z, Ms), atom_string(Z, SZ)), JW),
    facts:departments(Dp), maplist(j, Dp, JDp),
    findall([SL, Fl, Cl], (facts:level(L, Fl, Cl), atom_string(L, SL)), JLv),
    findall([SZ, SL, SK], (facts:zone(Z, L, K), maplist(atom_string, [Z, L, K], [SZ, SL, SK])), JZ),
    findall([SB, SZ, ST], (facts:bay(B, Z, T), maplist(atom_string, [B, Z, T], [SB, SZ, ST])), JBy),
    JB = json([levels=JLv, zones=JZ, bays=JBy]),
    findall(json([person=SP, role=SR, dest=SD, vehicle=SV, class=SC2, height=H2, anpr=An, arrival=Ar, stay=Sy]),
            (facts:driver(P, R, D, V, C, H2, An, Ar, Sy), maplist(atom_string, [P, R, D, V, C], [SP, SR, SD, SV, SC2])), JP).

main :-
    kb_json(KB), write_json('website/kb.json', KB),
    findall(J, (core:scen(S, _, _, _, _, _, _), result_json(S, J)), Rs), write_json('website/results.json', Rs),
    site_json(Site), write_json('website/site.json', Site),
    length(Rs, N), format("wrote website/kb.json, website/results.json (~w scenarios), website/site.json~n", [N]).
:- initialization(main, main).
