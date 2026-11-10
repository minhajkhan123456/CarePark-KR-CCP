/*  CarePark-KR semantic network: link(From, Relation, To).
    is_a and instance_of are inherited; part_of is transitive but not inherited; has_a parts are
    inherited down is_a; the rest are named relations.                                           */
:- module(semnet, [link/3, nodes/1, classes_of/2, inherited_parts/2, inherited_relations/2,
                   part_of_chain/2, path/3, relation_kinds/1]).
:- use_module(library(lists)).

% taxonomy of people
link('Staff', is_a, 'Person').            link('Patient', is_a, 'Person').           link('Visitor', is_a, 'Person').
link('Supplier', is_a, 'Person').         link('Doctor', is_a, 'Staff').             link('Nurse', is_a, 'Staff').
link('Paramedic', is_a, 'Staff').         link('AdminOfficer', is_a, 'Staff').       link('BadgeHolder', is_a, 'Person').
link('ExpectantMother', is_a, 'Person').  link('OnCallDoctor', is_a, 'Doctor').
% vehicles
link('Car', is_a, 'Vehicle').             link('SUV', is_a, 'Car').                  link('ElectricCar', is_a, 'Car').
link('Van', is_a, 'Vehicle').             link('WheelchairVan', is_a, 'Van').        link('Ambulance', is_a, 'Van').
link('Motorcycle', is_a, 'Vehicle').
% bays
link('AmbulanceBay', is_a, 'Bay').        link('AccessibleBay', is_a, 'Bay').        link('ChargerBay', is_a, 'Bay').
link('LoadingBay', is_a, 'Bay').          link('DropOffBay', is_a, 'Bay').           link('StandardBay', is_a, 'Bay').
link('FamilyBay', is_a, 'Bay').
% structure
link('Bay', part_of, 'Zone').             link('Zone', part_of, 'Level').            link('Level', part_of, 'CarPark').
link('Gate', part_of, 'CarPark').         link('Ramp', part_of, 'CarPark').          link('CarPark', part_of, 'Hospital').
link('Department', part_of, 'Hospital').
% components
link('Vehicle', has_a, 'NumberPlate').    link('ElectricCar', has_a, 'Battery').     link('ChargerBay', has_a, 'Charger').
link('Bay', has_a, 'OccupancySensor').    link('Gate', has_a, 'ANPRCamera').         link('Gate', has_a, 'Barrier').
link('CarPark', has_a, 'DisplayBoard').   link('Staff', has_a, 'StaffBadge').        link('Ambulance', has_a, 'Siren').
link('Level', has_a, 'Clearance').
% named relations
link('Person', drives, 'Vehicle').        link('Staff', works_in, 'Department').     link('Patient', has, 'Appointment').
link('Appointment', at, 'Department').    link('Visitor', visits, 'Department').     link('Supplier', delivers_to, 'Department').
link('Zone', walk_to, 'Department').      link('Vehicle', occupies, 'Bay').          link('ANPRCamera', reads, 'NumberPlate').
link('Ramp', limited_by, 'Clearance').    link('Paramedic', drives, 'Ambulance').    link('DisplayBoard', shows, 'Route').
% instances and their links
link(saad, instance_of, 'OnCallDoctor').  link(ev_sa, instance_of, 'ElectricCar').   link(saad, drives, ev_sa).
link(saad, works_in, cardiology).         link(cardiology, instance_of, 'Department').
link(noor, instance_of, 'Patient').       link(noor, instance_of, 'BadgeHolder').    link(wv_no, instance_of, 'WheelchairVan').
link(noor, drives, wv_no).                link(noor, has, appt_noor).                link(appt_noor, instance_of, 'Appointment').
link(appt_noor, at, oncology).            link(oncology, instance_of, 'Department').
link(faisal, instance_of, 'Paramedic').   link(amb_fa, instance_of, 'Ambulance').    link(faisal, drives, amb_fa).
link(amb1, instance_of, 'AmbulanceBay').  link(amb1, part_of, z_amb).                link(z_amb, instance_of, 'Zone').
link(z_amb, part_of, g).                  link(g, instance_of, 'Level').             link(rukhsana, instance_of, 'ExpectantMother').
link(rukhsana, instance_of, 'Visitor').   link(rukhsana, visits, maternity).         link(maternity, instance_of, 'Department').

inheriting(is_a). inheriting(instance_of).

nodes(Ns) :- findall(N, (link(A, _, B), (N = A ; N = B)), N0), list_to_set(N0, Ns).
relation_kinds(Ks) :- findall(R, link(_, R, _), Rs), msort(Rs, S), clumped(S, Ks).

classes_of(N, Cs) :- bfs([N], [], Cs0), Cs0 = [_|Cs].
bfs([], A, R) :- reverse(A, R).
bfs([X|Q], A, R) :- ( memberchk(X, A) -> bfs(Q, A, R)
                    ; findall(Y, (link(X, Rel, Y), inheriting(Rel)), Ys), append(Q, Ys, Q1), bfs(Q1, [X|A], R) ).

inherited_parts(N, Ps) :- classes_of(N, Cs), findall(C-P, (member(C, [N|Cs]), link(C, has_a, P)), Ps).
inherited_relations(N, Rs) :- classes_of(N, Cs), findall(C-R-T, (member(C, Cs), link(C, R, T), \+ inheriting(R), R \== has_a, R \== part_of), Rs).

part_of_chain(N, [P|Ps]) :- link(N, part_of, P), !, part_of_chain(P, Ps).
part_of_chain(_, []).

% path(+From, +To, -Steps): shortest path, links followed in both directions
path(A, B, Steps) :- bfs_path([[A]], B, [A], Rev), !, rev_steps(Rev, Steps).
bfs_path([[B|T]|_], B, _, [B|T]) :- !.
bfs_path([[X|T]|Q], B, Seen, P) :-
    findall([Y, X|T], ((link(X, _, Y) ; link(Y, _, X)), \+ memberchk(Y, Seen)), New),
    findall(Y, member([Y|_], New), Ys), append(Seen, Ys, Seen1),
    append(Q, New, Q1), bfs_path(Q1, B, Seen1, P).
rev_steps(Rev, Steps) :- reverse(Rev, Ns), pairs(Ns, Steps).
pairs([_], []).
pairs([A, B|T], [step(A, R, B)|S]) :- ( link(A, R0, B) -> R = R0 ; link(B, R1, A), atom_concat(R1, '^-1', R) ), pairs([B|T], S).
