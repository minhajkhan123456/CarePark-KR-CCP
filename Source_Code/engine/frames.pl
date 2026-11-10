/*  CarePark-KR frame system.
    frame(Name, Kind, Parents, Slots): Kind is class or instance; Parents allows multiple inheritance.
    Slot facets: value(V) | default(V) | type(T) | card(C) | if_needed(Goal) | if_added(Goal) | range(Lo-Hi).
    get/3 order: local value -> if-needed demon (own or inherited) -> inherited value (left-to-right,
    depth-first over parents) -> default facet. put/3 stores a value and runs if-added demons.
    The PARKING-VISIT script (10 scenes) sits at the bottom.                                     */
:- module(frames, [frame/4, get/3, get/4, put/3, isa_chain/2, slots_of/2, class_frames/1, instance_frames/1,
                   script/1, scene/5, demon_log/1, reset_frames/0]).
:- use_module(library(lists)).
:- use_module('../kb/facts', []).

:- dynamic frame/4, local/3, demon_log/1.

frame('Thing', class, [], []).
% ----- people
frame('Person', class, ['Thing'], [
    name-[type(text)], role-[type(role)], destination-[type(department)],
    drives-[type('Vehicle'), card('0..2')], banned-[type(boolean), default(false)],
    cleared-[type(boolean), if_needed(frames:d_cleared)]]).
frame('Staff', class, ['Person'], [
    badge_expiry-[type(date)], shift_start-[type(minute)], shift_end-[type(minute)],
    badge_valid-[type(boolean), if_needed(frames:d_badge_valid)], fee_band-[default(free)]]).
frame('Doctor', class, ['Staff'], [on_call-[type(boolean), default(false)], role-[value(doctor)]]).
frame('Nurse', class, ['Staff'], [role-[value(nurse)]]).
frame('Paramedic', class, ['Staff'], [role-[value(paramedic)], destination-[value(emergency)]]).
frame('AdminOfficer', class, ['Staff'], [role-[value(admin)], destination-[value(admin)]]).
frame('Patient', class, ['Person'], [
    appointment_time-[type(minute)], appointment_dept-[type(department)], role-[value(patient)],
    fee_band-[default('first 2 h free, then PKR 50/h')]]).
frame('Visitor', class, ['Person'], [ward-[type(department)], role-[value(visitor)], fee_band-[default('PKR 100 first hour, PKR 50/h after')]]).
frame('Supplier', class, ['Person'], [delivery_from-[type(minute)], delivery_to-[type(minute)], role-[value(supplier)], fee_band-[default(contract)]]).
frame('BadgeHolder', class, ['Person'], [disability_badge-[value(true)], preferred_zone-[default(accessible)]]).
frame('ExpectantMother', class, ['Person'], [preferred_zone-[default(maternity)], notify_ward-[default(true)]]).
% ----- vehicles
frame('Vehicle', class, ['Thing'], [
    plate-[type(text)], class-[type(vclass)], height_cm-[type(integer), range(80-400), default(150)],
    anpr_confidence-[type(percent)], arrival-[type(minute)], stay_min-[type(minute)],
    identified-[type(boolean), if_needed(frames:d_identified)],
    occupies-[type('Bay'), card('0..1'), if_added(frames:d_park)]]).
frame('Car', class, ['Vehicle'], [class-[default(car)], wheels-[default(4)]]).
frame('SUV', class, ['Car'], [class-[value(suv)], height_cm-[default(185)]]).
frame('ElectricCar', class, ['Car'], [class-[value(ev)], battery_pct-[type(percent)], needs_charge-[if_needed(frames:d_needs_charge)]]).
frame('Van', class, ['Vehicle'], [class-[value(van)], height_cm-[default(260)], max_level-[if_needed(frames:d_max_level)]]).
frame('WheelchairVan', class, ['Van'], [class-[value(wheelchair_van)], height_cm-[default(230)], ramp-[default(rear)]]).
frame('Ambulance', class, ['Van'], [class-[value(ambulance)], height_cm-[default(280)], siren-[default(true)]]).
frame('Motorcycle', class, ['Vehicle'], [class-[value(motorcycle)], wheels-[value(2)], height_cm-[default(120)]]).
% ----- facility
frame('Level', class, ['Thing'], [floor-[type(integer)], clearance_cm-[type(integer), default(210)]]).
frame('Zone', class, ['Thing'], [kind-[type(zone_kind)], level-[type('Level')], bays-[card('1..*')], penalty_m-[default(0)]]).
frame('Bay', class, ['Thing'], [bay_type-[default(std)], zone-[type('Zone')], status-[default(vacant)], width_m-[default(2.5)], sensor-[default(ultrasonic)]]).
frame('AmbulanceBay', class, ['Bay'], [bay_type-[value(amb)], width_m-[value(3.5)], keep_clear-[value(true)]]).
frame('AccessibleBay', class, ['Bay'], [bay_type-[value(acc)], width_m-[value(3.6)]]).
frame('ChargerBay', class, ['Bay'], [bay_type-[value(ev)], charger_kw-[default(22)]]).
frame('LoadingBay', class, ['Bay'], [bay_type-[value(load)], width_m-[value(4.0)], length_m-[default(9)]]).
frame('DropOffBay', class, ['Bay'], [bay_type-[value(drop)], max_stay_min-[default(15)]]).
frame('Department', class, ['Thing'], [entrance-[type(text)], walk_from_zone_m-[type(table)]]).
frame('Appointment', class, ['Thing'], [patient-[type('Patient')], time-[type(minute)], window-[default('-60 / +30 min')]]).
% ----- instances
frame(saad, instance, ['Doctor'], [name-[value('Dr Saad')], destination-[value(cardiology)], on_call-[value(true)], drives-[value(ev_sa)],
      badge_expiry-[value(20271231)], shift_start-[value(420)], shift_end-[value(1140)]]).
frame(noor, instance, ['Patient', 'BadgeHolder'], [name-[value('Noor')], appointment_time-[value(600)], appointment_dept-[value(oncology)], drives-[value(wv_no)]]).
frame(rukhsana, instance, ['Visitor', 'ExpectantMother'], [name-[value('Rukhsana')], ward-[value(maternity)], drives-[value(car_ru)]]).
frame(bushra, instance, ['AdminOfficer'], [name-[value('Bushra')], badge_expiry-[value(20261031)], drives-[value(car_bu)]]).
frame(waqar, instance, ['Visitor'], [name-[value('Waqar')], banned-[value(true)], drives-[value(car_wq)]]).
frame(ev_sa, instance, ['ElectricCar'], [plate-[value('KHI-EV-2210')], battery_pct-[value(22)], anpr_confidence-[value(98)], arrival-[value(425)]]).
frame(wv_no, instance, ['WheelchairVan'], [plate-[value('KHI-WV-0412')], anpr_confidence-[value(94)], arrival-[value(585)]]).
frame(amb_fa, instance, ['Ambulance'], [plate-[value('EDHI-118')], anpr_confidence-[value(99)], arrival-[value(540)]]).
frame(car_ya, instance, ['Car'], [plate-[value('KHI-??-81')], anpr_confidence-[value(64)], arrival-[value(905)]]).
frame(l1, instance, ['Level'], [floor-[value(1)]]).
frame(g, instance, ['Level'], [floor-[value(0)], clearance_cm-[value(400)]]).
frame(z_patient, instance, ['Zone'], [kind-[value(patient)], level-[value(l1)]]).
frame(amb1, instance, ['AmbulanceBay'], [zone-[value(z_amb)]]).
frame(ac1, instance, ['AccessibleBay'], [zone-[value(z_acc)]]).
frame(dr1, instance, ['DropOffBay'], [zone-[value(z_drop)]]).
frame(oncology, instance, ['Department'], [entrance-[value('Block C, ground')]]).

reset_frames :- retractall(local(_, _, _)), retractall(demon_log(_)).

% ---------------------------------------------------------------- inheritance
isa_chain(F, Chain) :- isa_bfs([F], [], Chain).
isa_bfs([], Acc, Chain) :- reverse(Acc, Chain).
isa_bfs([F|Q], Acc, Chain) :-
    ( memberchk(F, Acc) -> isa_bfs(Q, Acc, Chain)
    ; frame(F, _, Ps, _), append(Q, Ps, Q1), isa_bfs(Q1, [F|Acc], Chain) ).

facet(F, Slot, Facet) :- frame(F, _, _, Slots), memberchk(Slot-Fs, Slots), member(Facet, Fs).

get(F, Slot, V) :- get(F, Slot, V, _).
get(F, Slot, V, How) :-
    (   local(F, Slot, V) -> How = 'value put at run time'
    ;   facet(F, Slot, value(V)) -> How = 'local value'
    ;   isa_chain(F, [_|Up]), member(A, [F|Up]), facet(A, Slot, if_needed(G)), call(G, F, V) -> format(atom(How), 'if-needed demon of ~w', [A])
    ;   isa_chain(F, [_|Up]), member(A, Up), facet(A, Slot, value(V)) -> format(atom(How), 'inherited from ~w', [A])
    ;   isa_chain(F, Ch), member(A, Ch), facet(A, Slot, default(V)) -> format(atom(How), 'default facet of ~w', [A])
    ).

put(F, Slot, V) :-
    retractall(local(F, Slot, _)), assertz(local(F, Slot, V)),
    forall((isa_chain(F, Ch), member(A, Ch), facet(A, Slot, if_added(G))), call(G, F, V)).

slots_of(F, Slots) :- isa_chain(F, Ch), findall(S, (member(A, Ch), frame(A, _, _, Ss), member(S-_, Ss)), S0), list_to_ord_set(S0, Slots0), Slots = Slots0.
class_frames(L) :- findall(F, frame(F, class, _, _), L).
instance_frames(L) :- findall(F, frame(F, instance, _, _), L).

% ---------------------------------------------------------------- demons
d_badge_valid(F, V) :- get(F, badge_expiry, E), number(E), facts:today(T), ( E >= T -> V = true ; V = false ).
d_cleared(F, V) :- ( get(F, banned, true) -> V = false ; get(F, badge_valid, false) -> V = false ; V = true ).
d_identified(F, V) :- get(F, anpr_confidence, C), number(C), ( C >= 90 -> V = true ; V = false ).
d_needs_charge(F, V) :- get(F, battery_pct, P), number(P), ( P < 30 -> V = true ; V = false ).
d_max_level(F, V) :- get(F, height_cm, H), number(H), ( H > 210 -> V = ground_only ; V = any ).
d_park(F, Bay) :- assertz(demon_log(occupied(Bay, F))).

% ---------------------------------------------------------------- script
script('PARKING-VISIT').
% scene(N, Name, Actor, WhatHappens, RulesUsed)
scene(1,  'Approach',        'Driver',            'Vehicle joins the queue at gate G1; time of arrival recorded', [arrival]).
scene(2,  'Plate read',      'ANPR camera',       'Plate read with a confidence score; under 90% a guard checks it', [s1, w9]).
scene(3,  'Emergency check', 'Gate controller',   'Ambulance on a run or a declared emergency skips every other check', [a5, a6, p1, p2]).
scene(4,  'Identification',  'Gate controller',   'Look up the driver, role, badge, appointment, delivery slot or visit', [h1, h10, t1, t4]).
scene(5,  'Clearance',       'Security office',   'Badge in date, not banned, supplier inside its slot', [s4, s5, a1, a4]).
scene(6,  'Entry',           'Barrier',           'Barrier opens for an admitted vehicle, otherwise the first failing reason is shown', [a7]).
scene(7,  'Bay choice',      'Allocation engine', 'Fit and height, entitlement, cost in walking metres, priority; one bay chosen', [f1, e1, e15, c1, k9]).
scene(8,  'Guidance',        'Display board',     'Bay number and route (ground floor or ramp) shown; ward or trauma team notified', [w11, w12, w13]).
scene(9,  'Parking',         'Occupancy sensor',  'Sensor confirms the vehicle in the bay; status := occupied', [w2]).
scene(10, 'Stay and exit',   'Monitoring',        'Drop-off limits, charger use and blocked ambulance bays watched; fee charged on exit', [w3, w5, w8, m1, m7]).
