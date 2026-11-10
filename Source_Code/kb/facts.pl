/*  CarePark-KR : ground facts for Riverside General Hospital car park (fictional).
    Date of the run: 10 Nov 2026. Times are minutes after midnight (07:05 = 425).
    The tables below are expanded into ground facts by fact/1 (see bottom).          */
:- module(facts, [fact/1, today/1, departments/1]).

today(20261110).
departments([emergency, cardiology, oncology, maternity, opd, dialysis, pharmacy, admin]).

% ---------------------------------------------------------------- building
% level(Level, Floor, ClearanceOnTheWayInCm)  - route clearance: the internal ramp is 210 cm
level(g,    0, 400).
level(l1,   1, 210).
level(l2,   2, 210).
level(roof, 3, 210).

% zone(Zone, Level, Kind)
zone(z_amb,     g,    ambulance).
zone(z_drop,    g,    dropoff).
zone(z_acc,     g,    accessible).
zone(z_load,    g,    loading).
zone(z_ev,      g,    ev_charging).
zone(z_moto,    g,    moto).
zone(z_oncall,  l1,   oncall).
zone(z_staff,   l1,   staff).
zone(z_patient, l1,   patient).
zone(z_mat,     l1,   maternity).
zone(z_visit,   l2,   visitor).
zone(z_family,  l2,   family).
zone(z_roof,    roof, overflow).

% bay(Bay, Zone, BayType)
bay(amb1, z_amb, amb).      bay(amb2, z_amb, amb).
bay(dr1, z_drop, drop).     bay(dr2, z_drop, drop).
bay(ac1, z_acc, acc).       bay(ac2, z_acc, acc).
bay(ld1, z_load, load).
bay(ev1, z_ev, ev).         bay(ev2, z_ev, ev).
bay(mc1, z_moto, moto).     bay(mc2, z_moto, moto).
bay(oc1, z_oncall, std).    bay(oc2, z_oncall, std).
bay(st1, z_staff, std).     bay(st2, z_staff, std).     bay(st3, z_staff, std).    bay(st4, z_staff, std).
bay(pt1, z_patient, std).   bay(pt2, z_patient, std).   bay(pt3, z_patient, std).
bay(mt1, z_mat, family).
bay(vs1, z_visit, std).     bay(vs2, z_visit, std).     bay(vs3, z_visit, std).    bay(vs4, z_visit, std).
bay(fm1, z_family, family).
bay(rf1, z_roof, std).      bay(rf2, z_roof, std).      bay(rf3, z_roof, std).

out_of_service(vs4).                       % line painting on level 2

% class_fits(VehicleClass, BayType): which vehicle classes a bay type can physically take
class_fits(car, std).   class_fits(suv, std).   class_fits(ev, std).   class_fits(wheelchair_van, std).
class_fits(car, acc).   class_fits(suv, acc).   class_fits(ev, acc).   class_fits(wheelchair_van, acc).
class_fits(car, drop).  class_fits(suv, drop).  class_fits(ev, drop).  class_fits(wheelchair_van, drop).
class_fits(ambulance, drop).  class_fits(van, drop).
class_fits(car, family). class_fits(suv, family). class_fits(ev, family).
class_fits(ev, ev).
class_fits(ambulance, amb).
class_fits(van, load).
class_fits(motorcycle, moto).

% kind_penalty(ZoneKind, Metres): extra cost so some zones are only a fallback
kind_penalty(ambulance, 0).  kind_penalty(dropoff, 300).  kind_penalty(accessible, 0).
kind_penalty(loading, 0).    kind_penalty(ev_charging, 0). kind_penalty(moto, 0).
kind_penalty(oncall, 0).     kind_penalty(staff, 0).       kind_penalty(patient, 0).
kind_penalty(maternity, 0).  kind_penalty(visitor, 0).     kind_penalty(family, 0).
kind_penalty(overflow, 60).

% walking distance in metres from each zone to each department entrance
%            emergency card onco mat opd dialysis pharmacy admin
walk_row(z_amb,     [ 10, 180, 220, 200, 150, 210, 160, 190]).
walk_row(z_drop,    [ 20, 160, 200, 180, 120, 190, 130, 170]).
walk_row(z_acc,     [ 40, 120, 140, 130,  60, 150,  70, 110]).
walk_row(z_load,    [ 90, 200, 230, 210, 160, 220,  30, 140]).
walk_row(z_ev,      [ 70, 150, 170, 160, 100, 170,  90, 120]).
walk_row(z_moto,    [ 60, 170, 190, 170, 110, 180, 100, 130]).
walk_row(z_oncall,  [ 80,  50, 110, 120,  90, 120, 120, 100]).
walk_row(z_staff,   [110,  80, 100, 110,  70, 100, 110,  60]).
walk_row(z_patient, [130,  70,  45, 120,  50,  40,  90, 120]).
walk_row(z_mat,     [150, 120, 130,  35, 100, 140, 110, 130]).
walk_row(z_visit,   [160,  90, 110,  80,  90, 120, 120, 140]).
walk_row(z_family,  [170,  85, 120,  60, 100, 130, 130, 150]).
walk_row(z_roof,    [220, 160, 170, 150, 160, 180, 170, 180]).

visiting_window(660, 780).                 % 11:00-13:00
visiting_window(1020, 1200).               % 17:00-20:00
level_route(g, ground_floor).  level_route(l1, ramp_to_l1).  level_route(l2, ramp_to_l2).  level_route(roof, ramp_to_roof).

% ---------------------------------------------------------------- people and vehicles
% driver(Person, Role, Destination, Vehicle, Class, HeightCm, AnprConfidence, Arrival, StayMinutes)
driver(saad,     doctor,    cardiology, ev_sa,  ev,             150, 98,  425, 600).
driver(mariam,   nurse,     maternity,  mc_ma,  motorcycle,     120, 91,  400, 520).
driver(areeba,   doctor,    opd,        suv_ar, suv,            185, 96,  470, 700).
driver(imtiaz,   patient,   dialysis,   car_im, car,            150, 95,  465, 240).
driver(junaid,   supplier,  pharmacy,   van_ju, van,            260, 93,  520,  40).
driver(faisal,   paramedic, emergency,  amb_fa, ambulance,      280, 99,  540,  30).
driver(bushra,   admin,     admin,      car_bu, car,            150, 97,  560, 480).
driver(noor,     patient,   oncology,   wv_no,  wheelchair_van, 230, 94,  585, 180).
driver(kashif,   visitor,   cardiology, car_ks, car,            150, 92,  615,  20).
driver(sadia,    visitor,   cardiology, car_sd, car,            150, 96,  690,  90).
driver(rukhsana, visitor,   maternity,  car_ru, suv,            180, 95,  700, 240).
driver(waqar,    visitor,   opd,        car_wq, car,            150, 97,  705,  60).
driver(ghazala,  visitor,   emergency,  car_gh, car,            150, 90,  760,  25).
driver(tahir,    patient,   opd,        car_th, car,            150, 94,  840,  60).
driver(yasir,    visitor,   oncology,   car_ya, car,            150, 64,  905,  45).

% vehicles already in the car park at 06:00 (owner, since, planned stay)
parked(zubair, doctor, cardiology, ev_zb,  ev,  150, 360, 360, ev2).
parked(hamid,  nurse,  dialysis,   car_hm, car, 150, 380, 520, st1).
parked(lubna,  admin,  admin,      car_lb, car, 150, 400, 500, st2).

% attributes
on_call(saad).
battery(ev_sa, 22).   battery(ev_zb, 100).
disability_badge(noor).
expectant(rukhsana).
has_children(sadia).
security_ban(waqar).
emergency_run(amb_fa).
emergency_declared(car_gh).

% staff badge(Person, Issued, Expiry)
staff_badge(saad,   20250101, 20271231).
staff_badge(mariam, 20250601, 20270531).
staff_badge(areeba, 20240901, 20270831).
staff_badge(faisal, 20250101, 20261231).
staff_badge(bushra, 20241101, 20261031).          % expired ten days ago
staff_badge(zubair, 20250101, 20271231).
staff_badge(hamid,  20250101, 20271231).
staff_badge(lubna,  20250101, 20271231).

% shift(Person, Start, End)
shift(saad,   420, 1140).   shift(mariam, 420,  900).   shift(areeba, 480, 1200).
shift(faisal, 480, 1200).   shift(bushra, 540, 1020).   shift(zubair, 360, 1080).
shift(hamid,  420,  900).   shift(lubna,  480,  960).

appointment(imtiaz, dialysis, 480).     % 08:00
appointment(noor,   oncology, 600).     % 10:00
appointment(tahir,  opd,      660).     % 11:00, he arrives at 14:00

delivery_slot(junaid, 510, 570).        % 08:30-09:30

registered_vehicle(V) :- driver(_, _, _, V, _, _, _, _, _).
registered_vehicle(V) :- parked(P, _, _, V, _, _, _, _, _), P \== unknown.

mode(normal).
weather(clear).

% ---------------------------------------------------------------- expansion into ground facts
fact(today(D)) :- today(D).
fact(level_floor(L, F)) :- level(L, F, _).
fact(route_clearance(L, C)) :- level(L, _, C).
fact(zone_level(Z, L)) :- zone(Z, L, _).
fact(zone_kind(Z, K)) :- zone(Z, _, K).
fact(bay_zone(B, Z)) :- bay(B, Z, _).
fact(bay_type(B, T)) :- bay(B, _, T).
fact(out_of_service(B)) :- out_of_service(B).
fact(class_fits(C, T)) :- class_fits(C, T).
fact(kind_penalty(K, P)) :- kind_penalty(K, P).
fact(walk(Z, D, M)) :- walk_row(Z, Ms), departments(Ds), nth1(I, Ds, D), nth1(I, Ms, M).
fact(visiting_window(A, B)) :- visiting_window(A, B).
fact(level_route(L, R)) :- level_route(L, R).
fact(Role) :- ( driver(P, R, _, _, _, _, _, _, _) ; parked(P, R, _, _, _, _, _, _, _) ), R \== none, Role =.. [R, P].
fact(destination(P, D)) :- ( driver(P, _, D, _, _, _, _, _, _) ; parked(P, _, D, _, _, _, _, _, _) ), D \== none.
fact(drives(P, V)) :- ( driver(P, _, _, V, _, _, _, _, _) ; parked(P, _, _, V, _, _, _, _, _) ), P \== unknown.
fact(vclass(V, C)) :- ( driver(_, _, _, V, C, _, _, _, _) ; parked(_, _, _, V, C, _, _, _, _) ).
fact(height(V, H)) :- ( driver(_, _, _, V, _, H, _, _, _) ; parked(_, _, _, V, _, H, _, _, _) ).
fact(anpr(V, C)) :- driver(_, _, _, V, _, _, C, _, _).
fact(arrival(V, T)) :- driver(_, _, _, V, _, _, _, T, _).
fact(stay(V, S)) :- ( driver(_, _, _, V, _, _, _, _, S) ; parked(_, _, _, V, _, _, _, S, _) ).
fact(occupies(V, B)) :- parked(_, _, _, V, _, _, _, _, B).
fact(since(V, T)) :- parked(_, _, _, V, _, _, T, _, _).
fact(registered(V)) :- registered_vehicle(V).
fact(on_call(P)) :- on_call(P).
fact(battery(V, L)) :- battery(V, L).
fact(disability_badge(P)) :- disability_badge(P).
fact(expectant(P)) :- expectant(P).
fact(has_children(P)) :- has_children(P).
fact(security_ban(P)) :- security_ban(P).
fact(emergency_run(V)) :- emergency_run(V).
fact(emergency_declared(V)) :- emergency_declared(V).
fact(staff_badge(P, I, E)) :- staff_badge(P, I, E).
fact(shift(P, S, E)) :- shift(P, S, E).
fact(appointment(P, D, T)) :- appointment(P, D, T).
fact(delivery_slot(P, A, B)) :- delivery_slot(P, A, B).
fact(mode(M)) :- mode(M).
fact(weather(W)) :- weather(W).
