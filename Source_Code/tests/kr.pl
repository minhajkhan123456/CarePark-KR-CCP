:- begin_tests(frames, [setup(frames:reset_frames)]).
test(counts) :- frames:class_frames(C), length(C, NC), NC >= 25, frames:instance_frames(I), length(I, NI), NI >= 12.
test(multiple_inheritance) :- frames:isa_chain(noor, C), C = [noor, 'Patient', 'BadgeHolder', 'Person', 'Thing'].
test(default_from_second_parent) :- frames:get(noor, preferred_zone, accessible, H), sub_atom(H, _, _, _, 'BadgeHolder').
test(local_value) :- frames:get(saad, on_call, true, 'local value').
test(inherited_value) :- frames:get(saad, role, doctor, H), sub_atom(H, 0, _, _, inherited).
test(override) :- frames:get(wv_no, height_cm, 230, _), frames:get(amb_fa, height_cm, 280, _).
test(default) :- frames:get(ev_sa, wheels, 4, H), sub_atom(H, 0, _, _, default).
test(if_needed_badge) :- frames:get(bushra, badge_valid, false, _), frames:get(saad, badge_valid, true, _).
test(if_needed_cleared) :- frames:get(waqar, cleared, false, _), frames:get(noor, cleared, true, _), frames:get(bushra, cleared, false, _).
test(if_needed_identified) :- frames:get(car_ya, identified, false, _), frames:get(amb_fa, identified, true, _).
test(if_needed_charge) :- frames:get(ev_sa, needs_charge, true, _).
test(if_needed_height) :- frames:get(wv_no, max_level, ground_only, _).
test(if_added) :- frames:put(ev_sa, occupies, ev1), frames:demon_log(occupied(ev1, ev_sa)).
test(script) :- aggregate_all(count, frames:scene(_, _, _, _, _), 10).
:- end_tests(frames).

:- begin_tests(semantic_network).
test(size) :- semnet:nodes(N), length(N, NN), NN >= 55, aggregate_all(count, semnet:link(_, _, _), L), L >= 70.
test(inheritance) :- semnet:classes_of(ev_sa, ['ElectricCar', 'Car', 'Vehicle']).
test(multiple) :- semnet:classes_of(noor, C), subset(['Patient', 'BadgeHolder', 'Person'], C).
test(parts_inherited) :- semnet:inherited_parts(ev_sa, P), memberchk('ElectricCar'-'Battery', P), memberchk('Vehicle'-'NumberPlate', P).
test(relations_inherited) :- semnet:inherited_relations(saad, R), memberchk('Person'-drives-'Vehicle', R).
test(part_of_chain) :- semnet:part_of_chain(amb1, [z_amb, g]).
test(part_of_not_isa) :- semnet:classes_of(amb1, C), \+ memberchk('Zone', C).
test(path, [nondet]) :- semnet:path(noor, oncology, P), length(P, 2).
:- end_tests(semantic_network).

:- begin_tests(first_order_logic, [setup(allocate:run_day(none, _))]).
test(count) :- aggregate_all(count, fol:fol(_, _, _, _, _, _), N), N >= 32, aggregate_all(count, fol:fol(_, _, _, _, not_horn, _), M), M >= 16.
test(all_hold) :- fol:check_all(L), forall(member(_-R, L), R == holds).
test(f4_catches_two_classes) :- allocate:run_day(tc20, _), fol:check_all(L), memberchk(f4-violated, L).
test(f35_catches_staff_visitor) :- allocate:run_day(tc21, _), fol:check_all(L), memberchk(f35-violated, L).
test(f19_code_red) :- allocate:run_day(tc02, _), fol:check_all(L), memberchk(f19-holds, L).
test(f26_ambulance_bays) :- allocate:run_day(tc18, _), fol:check_all(L), memberchk(f26-holds, L).
:- end_tests(first_order_logic).

:- begin_tests(description_logic).
test(tbox) :- dl:tbox_size(N), N >= 80.
test(subsumption) :- dl:subsumes('Person', 'OnCallDoctor'), dl:subsumes('Vehicle', 'WheelchairVan'), \+ dl:subsumes('Car', 'Vehicle').
test(inferred) :- dl:inferred(I), memberchk('OnCallDoctor'-'Person', I), memberchk('Ambulance'-'Vehicle', I).
test(realisation) :- allocate:run_day(none, _), dl:most_specific(noor, C), memberchk('Patient', C), memberchk('BadgeHolder', C).
test(tall_vehicle) :- allocate:run_day(none, _), dl:abox(A), memberchk(wv_no-'TallVehicle', A), \+ memberchk(ev_sa-'TallVehicle', A).
test(consistent_baseline) :- allocate:run_day(none, _), dl:consistency([]).
test(blocked_ambulance_bay) :- allocate:run_day(tc16, _), dl:consistency(C), memberchk(forall_violation(amb1, 'AmbulanceBay', car_qx), C).
test(two_classes_clash) :- allocate:run_day(tc20, _), dl:consistency(C), C \== [].
test(staff_visitor_clash) :- allocate:run_day(tc21, _), dl:consistency(C), memberchk(clash(saad, 'Staff', 'Visitor'), C).
:- end_tests(description_logic).
