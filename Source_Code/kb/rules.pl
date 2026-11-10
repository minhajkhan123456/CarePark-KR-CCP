/*  CarePark-KR : Horn rules as data, r(Id, Head, Body).
    Body literals: an atom, not(Atom) for negation as failure (stratified),
    or a builtin: lt/2 le/2 gt/2 ge/2 eq/2 neq/2 add/3 sub/3 mul/3 cdiv/3 (ceiling division).
    Phase 1 rules decide admission, fit, entitlement, priority, cost and fees.
    Phase 2 rules (monitoring, guidance) also see assigned/2 facts written by the control layer. */
:- module(rules, [r/3, rule_text/2, rule_group/2, phase2/1, builtin/1, ic/4]).

builtin(F) :- memberchk(F, [lt, le, gt, ge, eq, neq, add, sub, mul, cdiv]).

% ---------------------------------------------------------------- roles and taxonomy
r(h1,  staff_member(P), [doctor(P)]).
r(h2,  staff_member(P), [nurse(P)]).
r(h3,  staff_member(P), [admin(P)]).
r(h4,  staff_member(P), [paramedic(P)]).
r(h5,  clinician(P),    [doctor(P)]).
r(h6,  clinician(P),    [nurse(P)]).
r(h7,  person(P),       [staff_member(P)]).
r(h8,  person(P),       [patient(P)]).
r(h9,  person(P),       [visitor(P)]).
r(h10, person(P),       [supplier(P)]).
r(h11, vehicle(V),      [vclass(V, _)]).
r(h12, ev(V),           [vclass(V, ev)]).
r(h13, motorcycle(V),   [vclass(V, motorcycle)]).
r(h14, car_like(V),     [vclass(V, car)]).
r(h15, car_like(V),     [vclass(V, suv)]).
r(h16, car_like(V),     [ev(V)]).
r(h17, emergency_vehicle(V), [vclass(V, ambulance), emergency_run(V)]).
r(h18, unregistered(V), [vehicle(V), not(registered(V))]).
% ---------------------------------------------------------------- sensors and records
r(s1,  identified(V),   [anpr(V, C), ge(C, 90)]).
r(s2,  battery_low(V),  [ev(V), battery(V, L), lt(L, 30)]).
r(s3,  charger_bay(B),  [bay_type(B, ev)]).
r(s4,  badge_valid(P),  [staff_badge(P, I, E), today(T), le(I, T), ge(E, T)]).
r(s5,  banned(P),       [security_ban(P)]).
r(s6,  code_red,        [mode(code_red)]).
r(s7,  raining,         [weather(rain)]).
% ---------------------------------------------------------------- time windows (each vehicle at its own arrival time)
r(t1,  on_shift(P),     [shift(P, S, E), drives(P, V), arrival(V, T), sub(S, 30, S0), ge(T, S0), le(T, E)]).
r(t2,  in_appointment_window(P), [appointment(P, _, T0), drives(P, V), arrival(V, T), sub(T0, 60, A), add(T0, 30, B), ge(T, A), le(T, B)]).
r(t3,  visiting_time(V), [arrival(V, T), visiting_window(A, B), ge(T, A), lt(T, B)]).
r(t4,  delivery_window(P), [delivery_slot(P, A, B), drives(P, V), arrival(V, T), ge(T, A), le(T, B)]).
% ---------------------------------------------------------------- admission
r(a1,  cleared(P),      [staff_member(P), badge_valid(P), not(banned(P))]).
r(a2,  cleared(P),      [patient(P), not(banned(P))]).
r(a3,  cleared(P),      [visitor(P), not(banned(P))]).
r(a4,  cleared(P),      [supplier(P), delivery_window(P), not(banned(P))]).
r(a5,  admitted(V),     [emergency_vehicle(V)]).
r(a6,  admitted(V),     [emergency_declared(V), arrival(V, _)]).
r(a7,  admitted(V),     [arrival(V, _), identified(V), drives(P, V), cleared(P)]).
% ---------------------------------------------------------------- physical fit (class and height clearance)
r(f1,  fits(V, B),      [vclass(V, C), bay_type(B, T), class_fits(C, T), height(V, H), bay_zone(B, Z),
                         zone_level(Z, L), route_clearance(L, Cl), le(H, Cl)]).
r(f2,  too_tall(V, L),  [height(V, H), route_clearance(L, Cl), gt(H, Cl)]).
r(f3,  bay_usable(B),   [bay_type(B, _), not(out_of_service(B))]).
% ---------------------------------------------------------------- entitlement by zone kind
r(e1,  entitled(V, Z),  [emergency_vehicle(V), zone_kind(Z, ambulance)]).
r(e2,  entitled(V, Z),  [admitted(V), zone_kind(Z, dropoff)]).
r(e3,  entitled(V, Z),  [drives(P, V), disability_badge(P), admitted(V), zone_kind(Z, accessible)]).
r(e4,  entitled(V, Z),  [drives(P, V), delivery_window(P), admitted(V), zone_kind(Z, loading)]).
r(e5,  entitled(V, Z),  [ev(V), admitted(V), zone_kind(Z, ev_charging)]).
r(e6,  entitled(V, Z),  [motorcycle(V), admitted(V), zone_kind(Z, moto)]).
r(e7,  entitled(V, Z),  [drives(P, V), on_call(P), on_shift(P), admitted(V), zone_kind(Z, oncall)]).
r(e8,  entitled(V, Z),  [drives(P, V), staff_member(P), on_shift(P), admitted(V), zone_kind(Z, staff)]).
r(e9,  entitled(V, Z),  [drives(P, V), in_appointment_window(P), admitted(V), zone_kind(Z, patient)]).
r(e10, entitled(V, Z),  [drives(P, V), expectant(P), admitted(V), zone_kind(Z, maternity)]).
r(e11, entitled(V, Z),  [drives(P, V), visitor(P), visiting_time(V), admitted(V), not(code_red), zone_kind(Z, visitor)]).
r(e12, entitled(V, Z),  [drives(P, V), has_children(P), visiting_time(V), admitted(V), not(code_red), zone_kind(Z, family)]).
r(e13, entitled(V, Z),  [drives(P, V), staff_member(P), on_shift(P), admitted(V), code_red, zone_kind(Z, visitor)]).
r(e14, entitled(V, Z),  [drives(P, V), staff_member(P), on_shift(P), admitted(V), zone_kind(Z, overflow)]).
r(e15, entitled(V, Z),  [drives(P, V), visitor(P), visiting_time(V), admitted(V), not(code_red), zone_kind(Z, overflow)]).
% ---------------------------------------------------------------- candidates, priority and cost
r(c1,  candidate(V, B), [admitted(V), fits(V, B), bay_zone(B, Z), entitled(V, Z), bay_usable(B)]).
r(p1,  priority(V, 0),  [emergency_vehicle(V)]).
r(p2,  priority(V, 0),  [emergency_declared(V), admitted(V)]).
r(p3,  priority(V, 1),  [drives(P, V), on_call(P), on_shift(P), admitted(V)]).
r(p4,  priority(V, 2),  [drives(P, V), disability_badge(P), admitted(V)]).
r(p5,  priority(V, 2),  [drives(P, V), expectant(P), admitted(V)]).
r(p6,  priority(V, 2),  [drives(P, V), in_appointment_window(P), admitted(V)]).
r(p7,  priority(V, 3),  [drives(P, V), staff_member(P), on_shift(P), admitted(V)]).
r(p8,  priority(V, 3),  [drives(P, V), delivery_window(P), admitted(V)]).
r(p9,  priority(V, 4),  [drives(P, V), visitor(P), admitted(V)]).
r(p10, priority(V, 5),  [admitted(V)]).
r(k1,  adjusted(V, B),  [candidate(V, B), battery_low(V), not(charger_bay(B))]).
r(k2,  adjusted(V, B),  [candidate(V, B), ev(V), not(battery_low(V)), charger_bay(B)]).
r(k3,  ev_adjust(V, B, 120), [candidate(V, B), battery_low(V), not(charger_bay(B))]).
r(k4,  ev_adjust(V, B, 40), [candidate(V, B), ev(V), not(battery_low(V)), charger_bay(B)]).
r(k5,  ev_adjust(V, B, 0),  [candidate(V, B), not(adjusted(V, B))]).
r(k6,  zone_cost(K, P), [kind_penalty(K, P), not(raining)]).
r(k7,  zone_cost(K, P), [kind_penalty(K, P0), raining, neq(K, overflow), eq(P0, P)]).
r(k8,  zone_cost(overflow, P), [kind_penalty(overflow, P0), raining, add(P0, 300, P)]).
r(k9,  cost(V, B, C),   [candidate(V, B), bay_zone(B, Z), drives(P, V), destination(P, D), walk(Z, D, W),
                         zone_kind(Z, K), zone_cost(K, Pen), ev_adjust(V, B, A), add(W, Pen, C1), add(C1, A, C)]).
r(k10, cost(V, B, C),   [candidate(V, B), emergency_vehicle(V), bay_zone(B, Z), walk(Z, emergency, W),
                         zone_kind(Z, K), zone_cost(K, Pen), add(W, Pen, C)]).
r(k11, cost(V, B, C),   [candidate(V, B), emergency_declared(V), bay_zone(B, Z), walk(Z, emergency, C)]).
% ---------------------------------------------------------------- tariff (PKR)
r(m1,  fee(V, 0),       [drives(P, V), staff_member(P), on_shift(P), admitted(V)]).
r(m2,  fee(V, 0),       [emergency_vehicle(V)]).
r(m3,  fee(V, 0),       [emergency_declared(V), admitted(V)]).
r(m4,  fee(V, 0),       [drives(P, V), supplier(P), admitted(V)]).
r(m5,  fee(V, 0),       [drives(P, V), patient(P), admitted(V), stay(V, M), le(M, 120)]).
r(m6,  fee(V, F),       [drives(P, V), patient(P), admitted(V), stay(V, M), gt(M, 120), sub(M, 120, X), cdiv(X, 60, H), mul(H, 50, F)]).
r(m7,  fee(V, F),       [drives(P, V), visitor(P), admitted(V), not(emergency_declared(V)), stay(V, M), cdiv(M, 60, H), sub(H, 1, H1), mul(H1, 50, X), add(100, X, F)]).
% ---------------------------------------------------------------- phase 2: monitoring and guidance (needs assigned/2)
r(w1,  occupant(V, B),  [occupies(V, B)]).
r(w2,  occupant(V, B),  [assigned(V, B)]).
r(w3,  ambulance_bay_blocked(B), [occupant(V, B), bay_type(B, amb), not(emergency_vehicle(V))]).
r(w4,  tow_request(B),  [ambulance_bay_blocked(B), occupant(V, B), unregistered(V)]).
r(w5,  charger_hog(V, B), [occupant(V, B), bay_type(B, ev), battery(V, L), ge(L, 95)]).
r(w6,  dropoff_limit(V, 30), [emergency_declared(V)]).
r(w7,  dropoff_limit(V, 15), [assigned(V, _), not(emergency_declared(V))]).
r(w8,  dropoff_overstay(V), [assigned(V, B), bay_type(B, drop), stay(V, M), dropoff_limit(V, L), gt(M, L)]).
r(w9,  manual_check(V), [arrival(V, _), anpr(V, C), lt(C, 90), not(emergency_vehicle(V))]).
r(w10, security_alert(P), [banned(P), drives(P, V), arrival(V, _)]).
r(w11, notify_ward(V, D), [assigned(V, _), drives(P, V), expectant(P), destination(P, D)]).
r(w12, route(V, B, R),  [assigned(V, B), bay_zone(B, Z), zone_level(Z, L), level_route(L, R)]).
r(w13, alert_trauma_team(V), [assigned(V, _), emergency_declared(V)]).
r(w14, height_warning(V), [arrival(V, _), too_tall(V, l1)]).

phase2(Id) :- atom_codes(Id, [0'w|_]).

rule_group(h, 'Roles and taxonomy').      rule_group(s, 'Sensors and records').
rule_group(t, 'Time windows').            rule_group(a, 'Admission').
rule_group(f, 'Physical fit').            rule_group(e, 'Entitlement by zone').
rule_group(c, 'Candidates').              rule_group(p, 'Priority classes').
rule_group(k, 'Cost and preferences').    rule_group(m, 'Tariff').
rule_group(w, 'Monitoring and guidance').

rule_text(h1, 'Doctors are staff').  rule_text(h2, 'Nurses are staff').  rule_text(h3, 'Admin officers are staff').
rule_text(h4, 'Paramedics are staff').  rule_text(h5, 'Doctors are clinicians').  rule_text(h6, 'Nurses are clinicians').
rule_text(h7, 'Staff are persons').  rule_text(h8, 'Patients are persons').  rule_text(h9, 'Visitors are persons').
rule_text(h10, 'Suppliers are persons').  rule_text(h11, 'Anything with a class is a vehicle').  rule_text(h12, 'Class ev is an EV').
rule_text(h13, 'Class motorcycle is a motorcycle').  rule_text(h14, 'Cars are car-like').  rule_text(h15, 'SUVs are car-like').
rule_text(h16, 'EVs are car-like').  rule_text(h17, 'An ambulance on a run is an emergency vehicle').
rule_text(h18, 'A vehicle with no registration is unregistered (NAF)').
rule_text(s1, 'Plate read at 90% or more identifies the vehicle').  rule_text(s2, 'EV battery under 30% is low').
rule_text(s3, 'EV bays have chargers').  rule_text(s4, 'Staff badge is valid today').  rule_text(s5, 'A security ban bans the person').
rule_text(s6, 'Code red mode is on').  rule_text(s7, 'It is raining').
rule_text(t1, 'On shift: from 30 min before start to shift end').  rule_text(t2, 'Appointment window: 60 min before to 30 min after').
rule_text(t3, 'Arrival inside a visiting window').  rule_text(t4, 'Arrival inside the delivery slot').
rule_text(a1, 'Staff with a valid badge, not banned, are cleared').  rule_text(a2, 'Patients not banned are cleared').
rule_text(a3, 'Visitors not banned are cleared').  rule_text(a4, 'Suppliers inside their slot are cleared').
rule_text(a5, 'Emergency vehicles are always admitted').  rule_text(a6, 'A declared emergency is admitted').
rule_text(a7, 'Identified vehicle with a cleared driver is admitted').
rule_text(f1, 'Class fits bay type and height fits route clearance').  rule_text(f2, 'Vehicle too tall for a level').
rule_text(f3, 'Bay not out of service is usable').
rule_text(e1, 'Ambulance zone for emergency vehicles').  rule_text(e2, 'Drop-off zone for anyone admitted').
rule_text(e3, 'Accessible zone for badge holders').  rule_text(e4, 'Loading dock inside the delivery slot').
rule_text(e5, 'EV zone for EVs').  rule_text(e6, 'Motorcycle zone for motorcycles').  rule_text(e7, 'On-call zone for on-call doctors on shift').
rule_text(e8, 'Staff zone for staff on shift').  rule_text(e9, 'Patient zone inside the appointment window').
rule_text(e10, 'Maternity bay for expectant mothers').  rule_text(e11, 'Visitor zone in visiting hours, unless code red').
rule_text(e12, 'Family bay for visitors with children, unless code red').  rule_text(e13, 'Code red gives the visitor zone to staff').
rule_text(e14, 'Roof overflow for staff on shift').  rule_text(e15, 'Roof overflow for visitors in visiting hours').
rule_text(c1, 'Candidate: admitted, fits, entitled, usable').
rule_text(p1, 'Priority 0: ambulance').  rule_text(p2, 'Priority 0: declared emergency').  rule_text(p3, 'Priority 1: on-call doctor').
rule_text(p4, 'Priority 2: disability badge').  rule_text(p5, 'Priority 2: expectant mother').  rule_text(p6, 'Priority 2: patient on time').
rule_text(p7, 'Priority 3: staff on shift').  rule_text(p8, 'Priority 3: delivery in slot').  rule_text(p9, 'Priority 4: visitor').
rule_text(p10, 'Priority 5: anyone admitted').
rule_text(k1, 'Low-battery EV off a charger needs an adjustment').  rule_text(k2, 'Charged EV on a charger needs an adjustment').
rule_text(k3, '+120 m: low battery but no charger').  rule_text(k4, '+40 m: charger taken by an EV that does not need it').
rule_text(k5, '+0 m otherwise (NAF)').  rule_text(k6, 'Zone penalty when dry').  rule_text(k7, 'Zone penalty in rain, covered zones').
rule_text(k8, 'Roof penalty +300 m in rain').  rule_text(k9, 'Cost = walk to destination + zone penalty + EV adjustment').
rule_text(k10, 'Ambulance cost = walk to emergency + penalty').  rule_text(k11, 'Declared emergency cost = walk to emergency').
rule_text(m1, 'Free for staff on shift').  rule_text(m2, 'Free for ambulances').  rule_text(m3, 'Free for emergencies').
rule_text(m4, 'Free for contracted suppliers').  rule_text(m5, 'Patients: first 2 h free').
rule_text(m6, 'Patients: PKR 50 per started hour after 2 h').  rule_text(m7, 'Visitors: PKR 100 first hour, PKR 50 per extra hour').
rule_text(w1, 'Pre-parked vehicles occupy bays').  rule_text(w2, 'Assigned vehicles occupy bays').
rule_text(w3, 'Ambulance bay held by a non-ambulance is blocked').  rule_text(w4, 'Tow an unregistered car blocking an ambulance bay').
rule_text(w5, 'A full EV on a charger is hogging it').  rule_text(w6, 'Drop-off limit 30 min for emergencies').
rule_text(w7, 'Drop-off limit 15 min otherwise').  rule_text(w8, 'Planned stay longer than the drop-off limit').
rule_text(w9, 'Plate read below 90%: manual check').  rule_text(w10, 'Banned person at the gate: alert security').
rule_text(w11, 'Tell the ward an expectant mother has arrived').  rule_text(w12, 'Route shown on the display board').
rule_text(w13, 'Declared emergency: alert the trauma team').  rule_text(w14, 'Warn when a vehicle cannot reach upper levels').

% ---------------------------------------------------------------- integrity constraints: ic(Id, Text, GoalClause, CheckGoal)
% CheckGoal runs over the saturated model kb:m/1 and the allocation kb:alloc/4 (vehicle, bay, from, to)
ic(ic1,  'one bay, two vehicles at the same time', ':- alloc(V1,B,F1,T1), alloc(V2,B,F2,T2), V1 \\= V2, F1 < T2, F2 < T1.',
       (alloc(V1, B, F1, T1), alloc(V2, B, F2, T2), V1 @< V2, F1 < T2, F2 < T1)).
ic(ic2,  'one vehicle, two bays at the same time', ':- alloc(V,B1,_,_), alloc(V,B2,_,_), B1 \\= B2.',
       (alloc(V, B1, _, _), alloc(V, B2, _, _), B1 @< B2)).
ic(ic3,  'vehicle taller than its route clearance', ':- alloc(V,B,_,_), height(V,H), bay_zone(B,Z), zone_level(Z,L), route_clearance(L,C), H > C.',
       (alloc(V, B, _, _), m(height(V, H)), m(bay_zone(B, Z)), m(zone_level(Z, L)), m(route_clearance(L, C)), H > C)).
ic(ic4,  'vehicle class cannot use the bay type', ':- alloc(V,B,_,_), vclass(V,C), bay_type(B,T), not class_fits(C,T).',
       (alloc(V, B, _, _), m(vclass(V, C)), m(bay_type(B, T)), \+ m(class_fits(C, T)))).
ic(ic5,  'vehicle driven by two people', ':- drives(P1,V), drives(P2,V), P1 \\= P2.',
       (m(drives(P1, V)), m(drives(P2, V)), P1 @< P2)).
ic(ic6,  'vehicle with two classes', ':- vclass(V,C1), vclass(V,C2), C1 \\= C2.',
       (m(vclass(V, C1)), m(vclass(V, C2)), C1 @< C2)).
ic(ic7,  'bay in two zones', ':- bay_zone(B,Z1), bay_zone(B,Z2), Z1 \\= Z2.',
       (m(bay_zone(B, Z1)), m(bay_zone(B, Z2)), Z1 @< Z2)).
ic(ic8,  'shift ends before it starts', ':- shift(P,S,E), E =< S.',
       (m(shift(_, S, E)), E =< S)).
ic(ic9,  'badge expires before it is issued', ':- staff_badge(P,I,E), E < I.',
       (m(staff_badge(_, I, E)), E < I)).
ic(ic10, 'appointment for someone who is not a patient', ':- appointment(P,_,_), not patient(P).',
       (m(appointment(P, _, _)), \+ m(patient(P)))).
ic(ic11, 'ambulance not driven by a paramedic', ':- vclass(V,ambulance), drives(P,V), not paramedic(P).',
       (m(vclass(V, ambulance)), m(drives(P, V)), \+ m(paramedic(P)))).
ic(ic12, 'vehicle parked in a bay that is out of service', ':- occupies(V,B), out_of_service(B).',
       (m(occupies(_, B)), m(out_of_service(B)))).
ic(ic13, 'staff role and visitor role on one person', ':- staff_member(P), visitor(P).',
       (m(staff_member(P)), m(visitor(P)))).
