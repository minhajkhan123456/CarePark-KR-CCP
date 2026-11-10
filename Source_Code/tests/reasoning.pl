:- begin_tests(forward_chaining, [setup(allocate:run_day(none, _))]).
test(admitted) :- forall(member(V, [ev_sa, mc_ma, suv_ar, car_im, van_ju, amb_fa, wv_no, car_ks, car_sd, car_ru, car_gh, car_th]), core:m(admitted(V))).
test(not_admitted) :- forall(member(V, [car_bu, car_wq, car_ya]), \+ core:m(admitted(V))).
test(taxonomy) :- core:m(staff_member(saad)), core:m(person(junaid)), core:m(clinician(mariam)), core:m(car_like(ev_sa)).
test(battery_low) :- core:m(battery_low(ev_sa)), \+ core:m(battery_low(ev_zb)).
test(on_shift_early_allowance) :- core:m(on_shift(mariam)).
test(appointment_window) :- core:m(in_appointment_window(imtiaz)), core:m(in_appointment_window(noor)), \+ core:m(in_appointment_window(tahir)).
test(visiting_time) :- core:m(visiting_time(car_sd)), \+ core:m(visiting_time(car_ks)).
test(delivery_window) :- core:m(delivery_window(junaid)).
test(badge_expired) :- \+ core:m(badge_valid(bushra)), core:m(badge_valid(saad)).
test(naf_ban) :- core:m(cleared(sadia)), \+ core:m(cleared(waqar)).
test(height_blocks_upper_levels, [nondet]) :- \+ core:m(fits(wv_no, pt1)), core:m(fits(wv_no, ac1)), core:m(too_tall(wv_no, l1)).
test(class_fit) :- \+ core:m(fits(van_ju, st1)), core:m(fits(van_ju, ld1)), core:m(fits(mc_ma, mc1)), \+ core:m(fits(mc_ma, st1)).
test(entitlement_zone_kinds) :- core:m(entitled(ev_sa, z_oncall)), core:m(entitled(car_im, z_patient)), core:m(entitled(car_ru, z_mat)),
    core:m(entitled(car_sd, z_family)), \+ core:m(entitled(car_ks, z_visit)), core:m(entitled(car_ks, z_drop)).
test(out_of_service) :- \+ core:m(bay_usable(vs4)), \+ core:m(candidate(car_sd, vs4)).
test(priorities) :- allocate:best_priority(amb_fa, 0), allocate:best_priority(car_gh, 0), allocate:best_priority(ev_sa, 1),
    allocate:best_priority(wv_no, 2), allocate:best_priority(suv_ar, 3), allocate:best_priority(car_sd, 4), allocate:best_priority(car_th, 5).
test(ev_adjust_low_battery) :- core:m(cost(ev_sa, ev1, 150)), core:m(cost(ev_sa, oc1, 170)).
test(cost_walk_plus_penalty) :- core:m(cost(car_ks, dr1, 460)).
test(emergency_cost, [nondet]) :- core:m(cost(car_gh, dr1, 20)).
test(fees) :- core:m(fee(car_im, 100)), core:m(fee(wv_no, 50)), core:m(fee(car_ks, 100)), core:m(fee(car_sd, 150)), core:m(fee(car_ru, 250)),
    core:m(fee(ev_sa, 0)), core:m(fee(amb_fa, 0)), core:m(fee(car_gh, 0)), core:m(fee(car_th, 0)).
test(no_duplicates) :- findall(F, core:m(F), L), sort(L, S), length(L, N), length(S, N).
test(phase2_routes) :- core:m(route(car_im, pt1, ramp_to_l1)), core:m(route(amb_fa, amb1, ground_floor)).
test(phase2_alerts) :- core:m(charger_hog(ev_zb, ev2)), core:m(dropoff_overstay(car_ks)), \+ core:m(dropoff_overstay(car_gh)),
    core:m(manual_check(car_ya)), core:m(security_alert(waqar)), core:m(notify_ward(car_ru, maternity)), core:m(alert_trauma_team(car_gh)).
test(height_warning) :- core:m(height_warning(wv_no)), core:m(height_warning(van_ju)), \+ core:m(height_warning(ev_sa)).
test(fixed_point) :- allocate:run_day(none, R), length(R.phase1, 808).
test(cycles) :- allocate:run_day(none, R), aggregate_all(max(C), member(fire(C, _, _, _, _), R.phase1), 9).
test(saturation_idempotent) :- findall(F, core:m(F), W), findall(I, core:phase1_rule(I), P1), core:saturate(W, P1, Log), Log == [].
test(log_order_respects_dependencies) :- allocate:run_day(none, R), once((
    nth1(I1, R.phase1, fire(_, _, _, identified(ev_sa), _)), nth1(I2, R.phase1, fire(_, _, _, admitted(ev_sa), _)), I1 < I2,
    nth1(I3, R.phase1, fire(_, _, _, candidate(ev_sa, ev1), _)), I2 < I3, nth1(I4, R.phase1, fire(_, _, _, cost(ev_sa, ev1, _), _)), I3 < I4)).
test(bindings_recorded) :- allocate:run_day(none, R), memberchk(fire(_, _, s1, identified(ev_sa), Bs), R.phase1), memberchk('V'=ev_sa, Bs), memberchk('C'=98, Bs).
:- end_tests(forward_chaining).

:- begin_tests(backward_chaining, [setup(backward:use_base(none))]).
test(proves_admission) :- backward:prove(admitted(wv_no), T, _), T = node(admitted(wv_no), a7, _).
test(naf_node) :- backward:prove(admitted(wv_no), T, _), once(sub_term(node(not(banned(noor)), naf, []), T)).
test(builtin_node) :- backward:prove(identified(ev_sa), T, _), once(sub_term(node(ge(98, 90), builtin, []), T)).
test(fails_for_bushra) :- backward:prove(admitted(car_bu), none, _).
test(trace_ports) :- backward:prove(admitted(car_bu), _, L), forall(member(P, ['CALL', 'EXIT', 'FAIL', 'TRY']), memberchk(_-P-_, L)).
test(redo_port) :- backward:prove(cost(ev_sa, ev1, _), _, L), memberchk(_-'REDO'-_, L).
test(binds_variables) :- backward:prove(fits(wv_no, B), _, _), nonvar(B).
test(all_answers) :- backward:prove_all(candidate(car_sd, _), A), length(A, 9).
test(agrees_with_forward_baseline) :-
    allocate:run_day(none, R), backward:use_base(none),
    forall((member(fire(_, _, Id, F, _), R.phase1), \+ sub_atom(Id, 0, 1, _, w)), backward:quiet_solve(F)).
test(agrees_with_forward_code_red) :-
    allocate:run_day(tc02, R), backward:use_base(tc02),
    forall(member(fire(_, _, _, F, _), R.phase1), backward:quiet_solve(F)).
test(agrees_with_forward_rain) :-
    allocate:run_day(tc05, R), backward:use_base(tc05),
    forall(member(fire(_, _, _, F, _), R.phase1), backward:quiet_solve(F)).
test(phase2_needs_allocation) :- backward:use_base_with_allocation(none), backward:prove(route(car_im, pt1, R), T, _), T \== none, R == ramp_to_l1.
:- end_tests(backward_chaining).

:- begin_tests(why_not, [setup(backward:use_base(none))]).
leaf(blocked(_, [why(_, _, S)|_]), L) :- !, leaf(S, L).
leaf(X, X).
test(provable_has_none) :- backward:why_not(admitted(ev_sa), none).
test(bushra_badge) :- backward:why_not(badge_valid(bushra), E), leaf(E, false_comparison(ge(20261031, 20261110))).
test(waqar_ban) :- backward:why_not(cleared(waqar), blocked(_, Ws)), memberchk(why(a3, not(banned(waqar)), holds(banned(waqar), _)), Ws).
test(yasir_plate) :- backward:why_not(identified(car_ya), E), leaf(E, false_comparison(ge(64, 90))).
test(noor_height) :- backward:why_not(fits(wv_no, pt1), E), leaf(E, false_comparison(le(230, 210))).
test(kashif_visiting) :- backward:why_not(visiting_time(car_ks), E), E = blocked(_, _).
test(tahir_window) :- backward:why_not(in_appointment_window(tahir), E), leaf(E, false_comparison(ge(840, 600))) -> true ; backward:why_not(in_appointment_window(tahir), E2), E2 = blocked(_, _).
test(missing_fact) :- backward:why_not(on_call(areeba), missing(on_call(areeba))).
:- end_tests(why_not).

:- begin_tests(agreement).
% every vehicle the forward chainer admits is proved backward, and every refused one fails backward
test(forward_backward_admitted) :-
    allocate:run_day(none, _), backward:use_base(none),
    forall(facts:fact(arrival(V, _)),
           ( core:m(admitted(V)) -> backward:quiet_solve(admitted(V)) ; \+ backward:quiet_solve(admitted(V)) )).
% the DL concept AdmittedVehicle holds exactly the vehicles the rules admit
test(dl_matches_rules) :-
    allocate:run_day(none, _), dl:abox(A),
    findall(V, member(V-'AdmittedVehicle', A), L1), sort(L1, S1),
    findall(V, (core:m(admitted(V)), facts:fact(arrival(V, _))), L2), sort(L2, S2),
    S1 == S2.
:- end_tests(agreement).
