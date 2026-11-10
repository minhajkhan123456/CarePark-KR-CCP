:- begin_tests(scenarios).
ok(Id) :- check:check_scenario(Id, P, Pr), ( P == pass -> true ; throw(failed(Id, Pr)) ).
test(tc01) :- ok(tc01).
test(tc02) :- ok(tc02).
test(tc03) :- ok(tc03).
test(tc04) :- ok(tc04).
test(tc05) :- ok(tc05).
test(tc06) :- ok(tc06).
test(tc07) :- ok(tc07).
test(tc08) :- ok(tc08).
test(tc09) :- ok(tc09).
test(tc10) :- ok(tc10).
test(tc11) :- ok(tc11).
test(tc12) :- ok(tc12).
test(tc13) :- ok(tc13).
test(tc14) :- ok(tc14).
test(tc15) :- ok(tc15).
test(tc16) :- ok(tc16).
test(tc17) :- ok(tc17).
test(tc18) :- ok(tc18).
test(tc19) :- ok(tc19).
test(tc20) :- ok(tc20).
test(tc21) :- ok(tc21).
test(tc22) :- ok(tc22).
:- end_tests(scenarios).

:- begin_tests(control_layer).
test(baseline_parked) :- allocate:run_day(none, _), aggregate_all(count, allocate:decision(_, allocate(_, _, _, _)), 12).
test(baseline_denied) :- allocate:run_day(none, _), aggregate_all(count, allocate:decision(_, denied(_)), 3).
test(cheapest_free_bay) :- allocate:run_day(none, _), allocate:decision(car_im, allocate(pt1, 40, 2, 0)).
test(ties_by_bay_id) :- allocate:run_day(none, _), allocate:alloc(suv_ar, st3, _, _).
test(bays_freed_on_departure) :- allocate:run_day(none, _), allocate:alloc(car_ks, dr1, 615, 635), allocate:alloc(car_gh, dr1, 760, 785).
test(no_overlap) :- allocate:run_day(none, _), \+ (allocate:alloc(V1, B, F1, T1), allocate:alloc(V2, B, F2, T2), V1 @< V2, F1 < T2, F2 < T1).
test(prepark_respected) :- allocate:run_day(none, _), \+ (allocate:alloc(_, st1, F, _), F < 900).
test(waiting_then_placed) :- allocate:run_day(tc19, _), allocate:decision(car_ks, allocate(dr1, _, _, 15)).
test(priority_order_same_minute) :- allocate:run_day(tc18, _), allocate:alloc(amb_fa, amb1, _, _), allocate:alloc(amb_rz, amb2, _, _).
test(denial_reasons) :- allocate:run_day(none, _), allocate:decision(car_bu, denied(badge_invalid)), allocate:decision(car_wq, denied(security_ban)),
    allocate:decision(car_ya, denied(plate_unreadable)).
test(delivery_denial) :- allocate:run_day(tc12, _), allocate:decision(van_ju, denied(outside_delivery_slot)).
test(no_violations_baseline) :- allocate:run_day(none, _), check:violations([]).
test(ic6_detected) :- allocate:run_day(tc20, _), check:violations(V), memberchk(ic6-_, V).
test(ic9_detected) :- allocate:run_day(tc22, _), check:violations(V), memberchk(ic9-_, V).
test(ic13_detected) :- allocate:run_day(tc21, _), check:violations(V), memberchk(ic13-_, V).
test(code_red_closes_visitor_zone) :- allocate:run_day(tc02, _), \+ core:m(entitled(car_sd, z_visit)), core:m(code_red).
test(rain_reorders) :- allocate:run_day(tc04, _), allocate:alloc(car_sd, rf1, _, _), allocate:run_day(tc05, _), allocate:alloc(car_sd, dr1, _, _).
test(events_sorted) :- allocate:run_day(none, _), allocate:day_events(E), pairs_keys(E, Ts), msort(Ts, Ts).
:- end_tests(control_layer).
