/*  CarePark-KR test scenarios.
    sc(Id, Title, Story, RemoveFacts, AddFacts, OutcomeChanges, Checks)
    OutcomeChanges lists only the vehicles whose outcome differs from the baseline below.
    Checks: alert(A) must hold after the day; ic(Id) must be violated; no_ic; wait(V, Minutes).   */
:- module(scenarios, [sc/7, baseline_outcomes/1]).

baseline_outcomes([mc_ma-mc1, ev_sa-ev1, car_im-pt1, suv_ar-st3, van_ju-ld1, amb_fa-amb1, car_bu-denied(badge_invalid),
                   wv_no-ac1, car_ks-dr1, car_sd-fm1, car_ru-mt1, car_wq-denied(security_ban), car_gh-dr1,
                   car_th-dr1, car_ya-denied(plate_unreadable)]).

sc(tc01, 'Ordinary Tuesday (baseline)',
   'Fifteen vehicles arrive between 06:40 and 15:05 while three cars parked overnight leave during the day.',
   [], [], [],
   [alert(charger_hog(ev_zb, ev2)), alert(dropoff_overstay(car_ks)), alert(security_alert(waqar)), alert(manual_check(car_ya)),
    alert(notify_ward(car_ru, maternity)), alert(alert_trauma_team(car_gh)), alert(height_warning(wv_no)), no_ic]).
sc(tc02, 'Code red at the emergency department',
   'Mass-casualty mode closes the visitor and family zones to visitors (e11, e12, e15). Sadia can only use drop-off, so Ghazala is sent to the second drop-off bay.',
   [mode(normal)], [mode(code_red)], [car_sd-dr1, car_gh-dr2], [alert(dropoff_overstay(car_sd)), no_ic]).
sc(tc03, 'Staff level full',
   'Bays st3 and st4 are closed for repairs and st1, st2 hold the night shift until 15:00, so Dr Areeba overflows to the roof (e14).',
   [], [out_of_service(st3), out_of_service(st4)], [suv_ar-rf1], [no_ic]).
sc(tc04, 'Visitor level closed, dry weather',
   'All visitor and family bays are out of service. Sadia\'s cheapest remaining bay is the roof (220 m with the 60 m roof penalty).',
   [], [out_of_service(vs1), out_of_service(vs2), out_of_service(vs3), out_of_service(fm1)], [car_sd-rf1], [no_ic]).
sc(tc05, 'Visitor level closed and raining',
   'Rain adds 300 m to the roof (k8), so the covered drop-off bay is now cheaper for Sadia even though her stay breaks the 15 minute limit.',
   [weather(clear)], [weather(rain), out_of_service(vs1), out_of_service(vs2), out_of_service(vs3), out_of_service(fm1)],
   [car_sd-dr1, car_gh-dr2], [alert(dropoff_overstay(car_sd)), no_ic]).
sc(tc06, 'Saad\'s EV is charged',
   'At 90% battery s2 no longer fires; a charger would cost +40 m (k4), so the on-call bay (130 m) beats the charger (190 m).',
   [battery(ev_sa, 22)], [battery(ev_sa, 90)], [ev_sa-oc1], [no_ic]).
sc(tc07, 'Saad off call with a charged EV',
   'Without on_call(saad) the on-call zone is closed to him; with a full battery the staff zone wins and Dr Areeba takes the next staff bay.',
   [on_call(saad), battery(ev_sa, 22)], [battery(ev_sa, 90)], [ev_sa-st3, suv_ar-st4], [no_ic]).
sc(tc08, 'Waqar\'s ban is lifted',
   'With no security_ban the NAF condition in a3 succeeds, so Waqar is cleared and parks in the visitor zone during visiting hours.',
   [security_ban(waqar)], [], [car_wq-vs1], [no_ic]).
sc(tc09, 'Yasir\'s plate re-read at 93%',
   'He is identified (s1), but 15:05 is between visiting windows, so drop-off is his only entitlement and his 45 minute stay is flagged.',
   [anpr(car_ya, 64)], [anpr(car_ya, 93)], [car_ya-dr1], [alert(dropoff_overstay(car_ya)), no_ic]).
sc(tc10, 'Bushra\'s badge is renewed',
   'With the expiry moved to Oct 2027 s4 holds, a1 clears her and she takes a staff bay near admin.',
   [staff_badge(bushra, 20241101, 20261031)], [staff_badge(bushra, 20241101, 20271031)], [car_bu-st4], [no_ic]).
sc(tc11, 'Accessible bays closed: Noor\'s van is too tall',
   'Noor\'s 230 cm wheelchair van cannot use the 210 cm ramp (f1), so the patient zone on L1 is out of reach. Only ground-floor drop-off remains, which pushes Kashif and Ghazala to dr2.',
   [], [out_of_service(ac1), out_of_service(ac2)], [wv_no-dr1, car_ks-dr2, car_gh-dr2], [alert(height_warning(wv_no)), alert(dropoff_overstay(wv_no)), no_ic]).
sc(tc12, 'Delivery van misses its slot',
   'Junaid arrives at 10:00; his slot ended at 09:30, so t4 fails, a4 does not clear him and the gate denies entry.',
   [arrival(van_ju, 520)], [arrival(van_ju, 600)], [van_ju-denied(outside_delivery_slot)], [no_ic]).
sc(tc13, 'Tahir arrives on time',
   'At 10:50 he is inside his appointment window (t2), so the patient zone opens to him; pt1 is still Imtiaz\'s, so he gets pt2.',
   [arrival(car_th, 840)], [arrival(car_th, 650)], [car_th-pt2], [no_ic]).
sc(tc14, 'Kashif visits in the evening',
   'At 17:10 he is inside the evening visiting window (t3), so he gets a visitor bay instead of drop-off.',
   [arrival(car_ks, 615)], [arrival(car_ks, 1030)], [car_ks-vs1], [no_ic]).
sc(tc15, 'Dr Areeba arrives two hours early',
   'At 05:30 she is more than 30 minutes before her shift, so t1 fails: no staff or roof entitlement, only drop-off, where she blocks dr1 for the day.',
   [arrival(suv_ar, 470)], [arrival(suv_ar, 330)], [suv_ar-dr1, car_ks-dr2, car_gh-dr2, car_th-dr2], [alert(dropoff_overstay(suv_ar)), no_ic]).
sc(tc16, 'Unknown car blocks an ambulance bay',
   'An unregistered car has been in amb1 since 05:00. The ambulance takes amb2; w3 and w4 raise a blocked-bay alert and a tow request.',
   [], [vclass(car_qx, car), height(car_qx, 150), occupies(car_qx, amb1), since(car_qx, 300), stay(car_qx, 9999)],
   [amb_fa-amb2], [alert(ambulance_bay_blocked(amb1)), alert(tow_request(amb1)), no_ic]).
sc(tc17, 'Both ambulance bays blocked',
   'With amb1 and amb2 both blocked, the ambulance (priority 0) falls back to the drop-off bay closest to the emergency entrance.',
   [], [vclass(car_qx, car), height(car_qx, 150), occupies(car_qx, amb1), since(car_qx, 300), stay(car_qx, 9999),
        vclass(car_qy, car), height(car_qy, 150), occupies(car_qy, amb2), since(car_qy, 320), stay(car_qy, 9999)],
   [amb_fa-dr1], [alert(tow_request(amb1)), alert(tow_request(amb2)), no_ic]).
sc(tc18, 'Two ambulances at 09:00',
   'A second ambulance arrives in the same minute. Both are priority 0, so arrival order decides and each gets an ambulance bay.',
   [], [paramedic(raza), drives(raza, amb_rz), destination(raza, emergency), vclass(amb_rz, ambulance), height(amb_rz, 280),
        anpr(amb_rz, 99), arrival(amb_rz, 540), stay(amb_rz, 30), emergency_run(amb_rz), registered(amb_rz),
        staff_badge(raza, 20250101, 20271231), shift(raza, 480, 1200)],
   [amb_rz-amb2], [no_ic]).
sc(tc19, 'Drop-off congestion: Kashif waits',
   'dr2 is closed and a taxi holds dr1 until 10:30. Kashif can only use drop-off, so he waits 15 minutes and is placed when the taxi leaves.',
   [], [out_of_service(dr2), vclass(taxi_1, car), height(taxi_1, 150), occupies(taxi_1, dr1), since(taxi_1, 600), stay(taxi_1, 30)],
   [car_gh-dr1], [wait(car_ks, 15), no_ic]).
sc(tc20, 'Inconsistent data: car with two classes',
   'The registry lists Sadia\'s car as both a car and an SUV. IC6 rejects the record and the DL reasoner reports the clash.',
   [], [vclass(car_sd, suv)], [], [ic(ic6)]).
sc(tc21, 'Inconsistent data: doctor recorded as a visitor',
   'Dr Saad also appears in the visitor list. IC13 flags a person holding a staff role and a visitor role at once.',
   [], [visitor(saad)], [], [ic(ic13)]).
sc(tc22, 'Inconsistent data: badge expires before issue',
   'A typing error sets Hamid\'s badge to expire in 2024 although it was issued in 2025. IC9 catches it.',
   [staff_badge(hamid, 20250101, 20271231)], [staff_badge(hamid, 20250101, 20241231)], [], [ic(ic9)]).
