:- encoding(utf8).
/*  CarePark-KR description logic layer (ALCHOIQ(D)-style TBox, checked offline).
    sub(C, D) atomic subsumption, disj(C, D) disjointness, def(Text) definitions and restrictions.
    The ABox is read from the saturated model; realisation, inferred subsumptions and consistency
    (disjointness clashes and universal restrictions) are computed here.                          */
:- module(dl, [sub/2, disj/2, def/1, tbox_size/1, ancestors/2, subsumes/2, inferred/1, abox/1, consistency/1, most_specific/2]).
:- use_module(core).
:- use_module(allocate).
:- use_module(library(lists)).

sub('Staff', 'Person').  sub('Patient', 'Person').  sub('Visitor', 'Person').  sub('Supplier', 'Person').
sub('Doctor', 'Staff').  sub('Nurse', 'Staff').  sub('Paramedic', 'Staff').  sub('AdminOfficer', 'Staff').
sub('Clinician', 'Staff').  sub('OnCallDoctor', 'Doctor').  sub('BadgeHolder', 'Person').  sub('ExpectantMother', 'Person').
sub('ClearedPerson', 'Person').  sub('BannedPerson', 'Person').  sub('OnShiftStaff', 'Staff').
sub('Car', 'Vehicle').  sub('SUV', 'Car').  sub('ElectricCar', 'Car').  sub('PetrolCar', 'Car').
sub('Van', 'Vehicle').  sub('WheelchairVan', 'Van').  sub('Ambulance', 'Van').  sub('Motorcycle', 'Vehicle').
sub('EmergencyVehicle', 'Vehicle').  sub('AdmittedVehicle', 'Vehicle').  sub('LowBatteryEV', 'ElectricCar').
sub('TallVehicle', 'Vehicle').  sub('UnregisteredVehicle', 'Vehicle').
sub('AmbulanceBay', 'Bay').  sub('AccessibleBay', 'Bay').  sub('ChargerBay', 'Bay').  sub('LoadingBay', 'Bay').
sub('DropOffBay', 'Bay').  sub('StandardBay', 'Bay').  sub('FamilyBay', 'Bay').  sub('ClosedBay', 'Bay').
sub('GroundZone', 'Zone').  sub('UpperZone', 'Zone').

disj('Staff', 'Visitor').  disj('Staff', 'Supplier').  disj('Patient', 'Supplier').  disj('Visitor', 'Supplier').
disj('Doctor', 'Nurse').  disj('Doctor', 'Paramedic').  disj('Doctor', 'AdminOfficer').  disj('Nurse', 'Paramedic').
disj('Nurse', 'AdminOfficer').  disj('Paramedic', 'AdminOfficer').
disj('Car', 'Van').  disj('Car', 'Motorcycle').  disj('Van', 'Motorcycle').  disj('ElectricCar', 'PetrolCar').
disj('SUV', 'ElectricCar').  disj('SUV', 'PetrolCar').
disj('AmbulanceBay', 'AccessibleBay').  disj('AmbulanceBay', 'ChargerBay').  disj('AmbulanceBay', 'StandardBay').
disj('AccessibleBay', 'StandardBay').  disj('ChargerBay', 'StandardBay').  disj('LoadingBay', 'StandardBay').
disj('DropOffBay', 'StandardBay').  disj('GroundZone', 'UpperZone').  disj('Person', 'Vehicle').  disj('Vehicle', 'Bay').
disj('ClearedPerson', 'BannedPerson').

def('PetrolCar ≡ Car ⊓ ¬ElectricCar ⊓ ¬SUV').
def('OnCallDoctor ≡ Doctor ⊓ ∃onCall.{true}').
def('Clinician ≡ Doctor ⊔ Nurse').
def('OnShiftStaff ≡ Staff ⊓ ∃shift.(∋ arrivalTime)').
def('ClearedPerson ≡ (Staff ⊓ ∃badge.ValidBadge ⊓ ¬BannedPerson) ⊔ ((Patient ⊔ Visitor) ⊓ ¬BannedPerson) ⊔ (Supplier ⊓ ∃slot.(∋ arrivalTime))').
def('AdmittedVehicle ≡ EmergencyVehicle ⊔ ∃declared.Emergency ⊔ (Identified ⊓ ∃drivenBy.ClearedPerson)').
def('EmergencyVehicle ≡ Ambulance ⊓ ∃onRun.{true}').
def('LowBatteryEV ≡ ElectricCar ⊓ ∃battery.(< 30)').
def('TallVehicle ≡ Vehicle ⊓ ∃height.(> 210)').
def('UnregisteredVehicle ≡ Vehicle ⊓ ¬Registered').
def('UpperZone ≡ Zone ⊓ ∃onLevel.(∃clearance.(≤ 210))').
def('TallVehicle ⊑ ∀parkedIn.(∃inZone.GroundZone)').
def('AmbulanceBay ⊑ ∀occupiedBy.EmergencyVehicle').
def('AccessibleBay ⊑ ∀occupiedBy.(∃drivenBy.BadgeHolder)').
def('ChargerBay ⊑ ∀occupiedBy.ElectricCar').
def('ChargerBay ⊑ ∃hasCharger.Charger').
def('Bay ⊑ (= 1 inZone.Zone)').
def('Zone ⊑ (= 1 onLevel.Level)').
def('Vehicle ⊑ (≤ 1 drivenBy.Person)').
def('Bay ⊑ (≤ 1 occupiedBy.Vehicle)').
def('Vehicle ⊑ (≤ 1 parkedIn.Bay)').
def('drivenBy ≡ drives⁻').
def('occupiedBy ≡ parkedIn⁻').
def('Patient ⊑ ∃has.Appointment ⊔ ∃visits.Department').

tbox_size(N) :- aggregate_all(count, sub(_, _), A), aggregate_all(count, disj(_, _), B), aggregate_all(count, def(_), C), N is A + B + C.

ancestors(C, As) :- anc([C], [], As0), subtract(As0, [C], As).
anc([], A, R) :- reverse(A, R).
anc([X|Q], A, R) :- ( memberchk(X, A) -> anc(Q, A, R) ; findall(Y, sub(X, Y), Ys), append(Q, Ys, Q1), anc(Q1, [X|A], R) ).
subsumes(G, S) :- ( G == S -> true ; ancestors(S, As), memberchk(G, As) ).
inferred(L) :- findall(C-D, (sub(C, _), ancestors(C, As), member(D, As), \+ sub(C, D)), L0), sort(L0, L).

% ABox from the model: concept(Individual, Concept)
map(doctor(X), X, 'Doctor').  map(nurse(X), X, 'Nurse').  map(paramedic(X), X, 'Paramedic').  map(admin(X), X, 'AdminOfficer').
map(patient(X), X, 'Patient').  map(visitor(X), X, 'Visitor').  map(supplier(X), X, 'Supplier').
map(disability_badge(X), X, 'BadgeHolder').  map(expectant(X), X, 'ExpectantMother').  map(cleared(X), X, 'ClearedPerson').
map(banned(X), X, 'BannedPerson').  map(on_shift(X), X, 'OnShiftStaff').
map(vclass(X, car), X, 'Car').  map(vclass(X, suv), X, 'SUV').  map(vclass(X, ev), X, 'ElectricCar').  map(vclass(X, van), X, 'Van').
map(vclass(X, wheelchair_van), X, 'WheelchairVan').  map(vclass(X, ambulance), X, 'Ambulance').  map(vclass(X, motorcycle), X, 'Motorcycle').
map(emergency_vehicle(X), X, 'EmergencyVehicle').  map(admitted(X), X, 'AdmittedVehicle').  map(battery_low(X), X, 'LowBatteryEV').
map(unregistered(X), X, 'UnregisteredVehicle').
map(bay_type(X, amb), X, 'AmbulanceBay').  map(bay_type(X, acc), X, 'AccessibleBay').  map(bay_type(X, ev), X, 'ChargerBay').
map(bay_type(X, load), X, 'LoadingBay').  map(bay_type(X, drop), X, 'DropOffBay').  map(bay_type(X, std), X, 'StandardBay').
map(bay_type(X, family), X, 'FamilyBay').  map(out_of_service(X), X, 'ClosedBay').

abox(A) :-
    findall(I-C, (map(P, I, C), m(P)), L0),
    findall(V-'TallVehicle', (m(height(V, H)), H > 210), L1),
    findall(V-'PetrolCar', (m(vclass(V, car))), L2),
    findall(D-'OnCallDoctor', (m(on_call(D)), m(doctor(D))), L3),
    findall(Z-K, (m(zone_level(Z, L)), (L == g -> K = 'GroundZone' ; K = 'UpperZone')), L4),
    append([L0, L1, L2, L3, L4], L5),
    findall(I-C2, (member(I-C, L5), (C2 = C ; ancestors(C, As), member(C2, As))), L6),
    sort(L6, A).

most_specific(I, Cs) :- abox(A), findall(C, member(I-C, A), All), findall(C, (member(C, All), \+ (member(D, All), D \== C, subsumes(C, D))), Cs).

consistency(Clashes) :-
    abox(A),
    findall(clash(I, C, D), (disj(C, D), member(I-C, A), memberchk(I-D, A)), L1),
    findall(forall_violation(B, 'AmbulanceBay', V), (occ(V, B), memberchk(B-'AmbulanceBay', A), \+ memberchk(V-'EmergencyVehicle', A)), L2),
    findall(forall_violation(B, 'ChargerBay', V), (occ(V, B), memberchk(B-'ChargerBay', A), \+ memberchk(V-'ElectricCar', A)), L3),
    findall(forall_violation(V, 'TallVehicle', B), (occ(V, B), memberchk(V-'TallVehicle', A), m(bay_zone(B, Z)), \+ memberchk(Z-'GroundZone', A)), L4),
    append([L1, L2, L3, L4], C0), sort(C0, Clashes).
occ(V, B) :- m(occupies(V, B)).
occ(V, B) :- alloc(V, B, _, _).
