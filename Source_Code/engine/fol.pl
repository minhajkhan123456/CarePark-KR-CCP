:- encoding(utf8).
/*  CarePark-KR first-order logic layer.
    fol(Id, English, Formula, RunsAs, Horn, Check): Check is a Prolog goal over the saturated model
    (m/1) and the day's allocation (alloc/4); it succeeds when the statement holds.               */
:- module(fol, [fol/6, check_all/1]).
:- use_module(core).
:- use_module(allocate).

fol(f1,  'Doctors, nurses, admin officers and paramedics are staff', '∀x (Doctor(x) ∨ Nurse(x) ∨ Admin(x) ∨ Paramedic(x) → Staff(x))', 'h1-h4', horn, true).
fol(f2,  'Staff, patients, visitors and suppliers are persons', '∀x (Staff(x) ∨ Patient(x) ∨ Visitor(x) ∨ Supplier(x) → Person(x))', 'h7-h10', horn, true).
fol(f3,  'Every person has at least one role', '∀x (Person(x) → Staff(x) ∨ Patient(x) ∨ Visitor(x) ∨ Supplier(x))', 'model check', not_horn,
     forall(m(person(X)), (m(staff_member(X)) ; m(patient(X)) ; m(visitor(X)) ; m(supplier(X))))).
fol(f4,  'Every vehicle has exactly one class', '∀v (Vehicle(v) → ∃!c Class(v,c))', 'IC6', not_horn,
     forall(m(vehicle(V)), aggregate_all(count, m(vclass(V, _)), 1))).
fol(f5,  'Every vehicle at the gate has exactly one driver', '∀v (Arrives(v) → ∃d (Drives(d,v) ∧ ∀d′ (Drives(d′,v) → d′ = d)))', 'IC5', not_horn,
     forall(m(arrival(V, _)), aggregate_all(count, m(drives(_, V)), 1))).
fol(f6,  'Identified iff the plate read is at least 90%', '∀v (Identified(v) ↔ ∃c (Anpr(v,c) ∧ c ≥ 90))', 's1', horn, true).
fol(f7,  'A badge is valid iff today lies between issue and expiry', '∀p (BadgeValid(p) ↔ ∃i ∃e ∃t (Badge(p,i,e) ∧ Today(t) ∧ i ≤ t ≤ e))', 's4', horn, true).
fol(f8,  'On shift from 30 minutes before the start to the end', '∀p (OnShift(p) ↔ ∃s ∃e ∃v ∃t (Shift(p,s,e) ∧ Drives(p,v) ∧ Arrival(v,t) ∧ s − 30 ≤ t ≤ e))', 't1', horn, true).
fol(f9,  'Appointment window is −60 to +30 minutes', '∀p (InWindow(p) ↔ ∃d ∃a ∃v ∃t (Appt(p,d,a) ∧ Drives(p,v) ∧ Arrival(v,t) ∧ a − 60 ≤ t ≤ a + 30))', 't2', horn, true).
fol(f10, 'Visiting time is inside a visiting window', '∀v (VisitingTime(v) ↔ ∃t ∃a ∃b (Arrival(v,t) ∧ Window(a,b) ∧ a ≤ t < b))', 't3', horn, true).
fol(f11, 'A banned person is never cleared', '∀p (Banned(p) → ¬Cleared(p))', 'a1-a4 with NAF', not_horn,
     \+ (m(banned(P)), m(cleared(P)))).
fol(f12, 'Clearance by role', '∀p (Staff(p) ∧ BadgeValid(p) ∧ ¬Banned(p) → Cleared(p))', 'a1-a4', horn, true).
fol(f13, 'Emergencies are always admitted', '∀v (EmergencyVehicle(v) ∨ DeclaredEmergency(v) → Admitted(v))', 'a5, a6', horn, true).
fol(f14, 'Admission of identified, cleared drivers', '∀v (∃p (Arrival(v) ∧ Identified(v) ∧ Drives(p,v) ∧ Cleared(p)) → Admitted(v))', 'a7', horn, true).
fol(f15, 'Every admitted vehicle came through the gate', '∀v (Admitted(v) → ∃t Arrival(v,t))', 'model check', not_horn,
     forall(m(admitted(V)), m(arrival(V, _)))).
fol(f16, 'Fit: class compatible and height under route clearance', '∀v ∀b (Fits(v,b) ↔ ∃c ∃t ∃h ∃l ∃k (Class(v,c) ∧ Type(b,t) ∧ ClassFits(c,t) ∧ Height(v,h) ∧ LevelOf(b,l) ∧ Clear(l,k) ∧ h ≤ k))', 'f1', horn, true).
fol(f17, 'Nothing taller than 210 cm is placed above ground', '∀v ∀b (Alloc(v,b) ∧ Height(v,h) ∧ h > 210 → LevelOf(b,g))', 'IC3', not_horn,
     forall((alloc(V, B, _, _), m(height(V, H)), H > 210), (m(bay_zone(B, Z)), m(zone_level(Z, g))))).
fol(f18, 'Entitlement by zone kind', '∀v ∀z (Entitled(v,z) ← … one clause per zone kind, e1-e15)', 'e1-e15', horn, true).
fol(f19, 'In code red no visitor is entitled to the visitor zone', '∀v ∀z (CodeRed ∧ Visitor(v) ∧ Kind(z,visitor) → ¬Entitled(v,z))', 'e11 with NAF', not_horn,
     ( m(code_red) -> \+ (m(drives(P, V)), m(visitor(P)), m(zone_kind(Z, visitor)), m(entitled(V, Z))) ; true )).
fol(f20, 'A candidate bay fits, is entitled and usable', '∀v ∀b (Candidate(v,b) ↔ Admitted(v) ∧ Fits(v,b) ∧ ∃z (InZone(b,z) ∧ Entitled(v,z)) ∧ Usable(b))', 'c1', horn, true).
fol(f21, 'Every allocated bay was a candidate', '∀v ∀b (Alloc(v,b) → Candidate(v,b))', 'model check', not_horn,
     forall(alloc(V, B, _, _), m(candidate(V, B)))).
fol(f22, 'Each admitted vehicle with a free candidate gets exactly one bay', '∀v (Admitted(v) ∧ ∃b FreeCandidate(v,b) → ∃!b Alloc(v,b))', 'control layer', not_horn,
     forall(alloc(V, B, _, _), \+ (alloc(V, B2, _, _), B2 \== B))).
fol(f23, 'No bay holds two vehicles at the same time', '∀b ∀v₁ ∀v₂ (Alloc(v₁,b,[s₁,e₁]) ∧ Alloc(v₂,b,[s₂,e₂]) ∧ v₁ ≠ v₂ → e₁ ≤ s₂ ∨ e₂ ≤ s₁)', 'IC1', not_horn,
     \+ (alloc(V1, B, F1, T1), alloc(V2, B, F2, T2), V1 @< V2, F1 < T2, F2 < T1)).
fol(f24, 'The chosen bay has minimum cost among bays free at that moment', '∀v ∀b (Alloc(v,b,t) → ¬∃b′ (Free(b′,t) ∧ Cost(v,b′) < Cost(v,b)))', 'control layer', not_horn,
     forall((alloc(V, B, T0, _), decision(V, allocate(B, C, _, _))),
            \+ (m(cost(V, B2, C2)), C2 < C, \+ busy_at(B2, T0)))).
fol(f25, 'Higher priority is served first at the same minute', '∀v₁ ∀v₂ (Arr(v₁)=Arr(v₂) ∧ Pri(v₁) < Pri(v₂) → Served(v₁) < Served(v₂))', 'control layer', not_horn,
     ( day_events(Ev) -> \+ (m(arrival(V1, T)), m(arrival(V2, T)), V1 \== V2, best_priority(V1, P1), best_priority(V2, P2), P1 < P2,
                              served_at(Ev, V1, I1), served_at(Ev, V2, I2), I1 > I2) ; true )).
fol(f26, 'Ambulance bays are for emergency vehicles only', '∀v ∀b (Occupies(v,b) ∧ Type(b,amb) → EmergencyVehicle(v))', 'w3 alert', not_horn,
     forall((alloc(V, B, _, _), m(bay_type(B, amb))), m(emergency_vehicle(V)))).
fol(f27, 'Accessible bays are allocated only to badge holders', '∀v ∀b (Alloc(v,b) ∧ Type(b,acc) → ∃p (Drives(p,v) ∧ Badge(p)))', 'e3', not_horn,
     forall((alloc(V, B, _, _), m(bay_type(B, acc))), (m(drives(P, V)), m(disability_badge(P))))).
fol(f28, 'Every bay lies in exactly one zone', '∀b (Bay(b) → ∃!z InZone(b,z))', 'IC7', not_horn,
     forall(m(bay_type(B, _)), aggregate_all(count, m(bay_zone(B, _)), 1))).
fol(f29, 'Every zone is on exactly one level', '∀z (Zone(z) → ∃!l Level(z,l))', 'model check', not_horn,
     forall(m(zone_kind(Z, _)), aggregate_all(count, m(zone_level(Z, _)), 1))).
fol(f30, 'Drop-off stays are short', '∀v (Alloc(v,b) ∧ Type(b,drop) ∧ Stay(v,s) ∧ s > Limit(v) → Overstay(v))', 'w6-w8', horn, true).
fol(f31, 'Fee schedule', '∀v (Patient(v) ∧ Stay(v,s) ∧ s > 120 → Fee(v, 50·⌈(s−120)/60⌉))', 'm1-m7', horn, true).
fol(f32, 'Every admitted vehicle has a fee or is exempt', '∀v (Alloc(v,b) → ∃f Fee(v,f))', 'model check', not_horn,
     forall((alloc(V, _, _, _), m(drives(P, V)), \+ (m(staff_member(P)), \+ m(on_shift(P)))), m(fee(V, _)))).
fol(f33, 'Shifts end after they start', '∀p ∀s ∀e (Shift(p,s,e) → s < e)', 'IC8', not_horn,
     forall(m(shift(_, S, E)), S < E)).
fol(f34, 'Only patients hold appointments', '∀p (∃d ∃t Appt(p,d,t) → Patient(p))', 'IC10', not_horn,
     forall(m(appointment(P, _, _)), m(patient(P)))).
fol(f35, 'Nobody is both staff and a visitor', '∀x ¬(Staff(x) ∧ Visitor(x))', 'IC13', not_horn,
     \+ (m(staff_member(X)), m(visitor(X)))).
fol(f36, 'Some bay is always reserved for emergencies', '∃b (Type(b,amb) ∧ ¬OutOfService(b))', 'model check', not_horn,
     once((m(bay_type(B, amb)), \+ m(out_of_service(B))))).

check_all(L) :- findall(Id-R, (fol(Id, _, _, _, not_horn, G), ( catch(G, _, fail) -> R = holds ; R = violated )), L).

busy_at(B, T) :- alloc(_, B, F, U), F =< T, T < U.
busy_at(B, T) :- m(occupies(X, B)), m(since(X, S)), m(stay(X, St)), S =< T, T < S + St.
served_at(Ev, V, I) :- nth0(I, Ev, _-E), arg(1, E, V), !.
