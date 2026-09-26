using { /Verse.org/Simulation }
using { /Verse.org/SpatialMath }
using { GameData.ScenarioData.Definitions }

flow_recording_target := class(target):
    var Positions : []vector3 = array{vector3{}}
    var Destinations : []vector3 = array{}
    var Durations : []float = array{}
    var CallTimes : []float = array{}
    var Indices : []int = array{}
    var MovesByIndex : [int]int = map{}
    MaxMoves : int = 8
    SuspendMoves : logic = false

    GetTargetPositions<override>()<transacts> : []vector3 = Positions
    GetTargetSpacing<override>()<transacts> : float = 0.0
    MoveTo<override>(Index : int, Destination : vector3, Duration : float)<suspends> : void =
        set Destinations += array{Destination}
        set Durations += array{Duration}
        set CallTimes += array{GetSimulationElapsedTime()}
        set Indices += array{Index}
        Count := if(PreviousCount := MovesByIndex[Index]) then PreviousCount + 1 else 1
        if(set MovesByIndex[Index] = Count) {}
        if(SuspendMoves?):
            Sleep(Duration)
        if(Count <= MaxMoves):
            if(set Positions[Index] = Destination) {}

FlowCheckRoutes(A : flow_recording_target, B : flow_recording_target)<transacts> : logic =
    if(A.Destinations.Length <> B.Destinations.Length):
        return false
    for(I -> P : A.Destinations):
        if(Q := B.Destinations[I], Distance(P, Q) < 0.00001) {}
        else:
            return false
    true

RunFlowChecks<public>()<suspends> : logic =
    if(not CheckFlowGeometry()?):
        Print("Flow checks FAILED: geometry, bounds, random streams or protection.")
        return false
    Box := target_spawn_box_bounds{Center := vector3{}, Width := 1400.0, Height := 1000.0, Depth := 1400.0}
    Config := flow_configuration{Seed := 12345, PlayerClearance := 0.0, ExperimentalSleep := false}
    Shared := flow_movement{Configuration := Config}
    A := flow_recording_target{}
    B := flow_recording_target{Positions := array{vector3{}, vector3{}}}
    # Reference streams run separately.
    RefA := flow_recording_target{}
    RefB := flow_recording_target{Positions := array{vector3{}, vector3{}}}
    Shared.Run(RefA, 0, Box)
    Shared.Run(RefB, 1, Box)
    # Interleaving may not change either stream, even with the same behavior instance.
    sync:
        Shared.Run(A, 0, Box)
        Shared.Run(B, 1, Box)
    if:
        FlowCheckRoutes(A, RefA)?
        FlowCheckRoutes(B, RefB)?
        not FlowCheckRoutes(A, B)?
        A.Destinations.Length = 9
        B.Destinations.Length = 9
        B.Indices[0] = 1
        B.Indices[8] = 1
    then {}
    else:
        Print("Flow checks FAILED: per-Run streams, indices or failed-arrival termination.")
        return false
    SameObject := flow_recording_target{Positions := array{vector3{}, vector3{}}}
    sync:
        Shared.Run(SameObject, 0, Box)
        Shared.Run(SameObject, 1, Box)
    for(Index := 0..1):
        Route := for(I -> P : SameObject.Destinations, SameObject.Indices[I] = Index):
            P
        Reference := if(Index = 0) then RefA else RefB
        if(Route.Length <> Reference.Destinations.Length):
            Print("Flow checks FAILED: shared target object counts.")
            return false
        for(I -> P : Route):
            if(Q := Reference.Destinations[I], Distance(P, Q) < 0.00001) {}
            else:
                Print("Flow checks FAILED: shared target object mixed streams.")
                return false
    var Previous : vector3 = vector3{}
    for(I -> Destination : A.Destinations):
        if(Duration := A.Durations[I], Abs(Duration * Config.Speed - Distance(Previous, Destination)) < 0.001) {}
        else:
            Print("Flow checks FAILED: requested speed.")
            return false
        set Previous = Destination

    # Restart must anchor to the new actual position and preserve the inactive coordinate.
    Restart := flow_recording_target{Positions := array{vector3{Forward := 75.0, Left := 100.0}}}
    Shared.Run(Restart, 0, Box)
    if(Restart.Destinations[0].Forward = 75.0) {}
    else:
        Print("Flow checks FAILED: restart plane.")
        return false
    NoOp := flow_recording_target{MaxMoves := 0}
    Shared.Run(NoOp, 0, Box)
    if(NoOp.Destinations.Length <> 1):
        Print("Flow checks FAILED: no-op adapter.")
        return false
    Invalid := flow_recording_target{}
    Shared.Run(Invalid, 9, Box)
    Shared.Run(Invalid, 0, target_spawn_radial_bounds{})
    Shared.Run(Invalid, 0, target_spawn_box_bounds{Width := -1.0})
    if(Invalid.Destinations.Length <> 0):
        Print("Flow checks FAILED: invalid inputs moved.")
        return false

    if(Region := BuildFlowRegion[Box, Config, vector3{}]):
        WithSleep := flow_configuration{PlayerClearance := 0.0, ExperimentalSleep := true}
        SleepTarget := flow_recording_target{}
        Started := GetSimulationElapsedTime()
        FirstResult := Shared.MoveChecked(SleepTarget, 0, vector3{}, vector3{Left := 40.0}, Region, WithSleep, true)
        SecondStarted := GetSimulationElapsedTime()
        SecondResult := Shared.MoveChecked(SleepTarget, 0, vector3{Left := 40.0}, vector3{Left := 40.0, Up := 40.0}, Region, WithSleep, true)
        if:
            FirstResult = flow_move_result.Arrived
            SecondResult = flow_move_result.Arrived
            SleepTarget.CallTimes[0] - Started >= 0.09
            SleepTarget.CallTimes[1] - SecondStarted >= 0.09
        then {}
        else:
            Print("Flow checks FAILED: Sleep must precede EVERY curved MoveTo.")
            return false
        Straight := flow_recording_target{}
        StraightStarted := GetSimulationElapsedTime()
        StraightResult := Shared.MoveChecked(Straight, 0, vector3{}, vector3{Up := 100.0}, Region, WithSleep, false)
        if(StraightResult = flow_move_result.Arrived, Straight.CallTimes[0] = StraightStarted) {}
        else:
            Print("Flow checks FAILED: experimental Sleep leaked into a straight leg.")
            return false
        WithoutSleep := flow_recording_target{}
        NoSleepStarted := GetSimulationElapsedTime()
        NoSleepResult := Shared.MoveChecked(WithoutSleep, 0, vector3{}, vector3{Up := 40.0}, Region, Config, true)
        if(NoSleepResult = flow_move_result.Arrived, WithoutSleep.CallTimes[0] = NoSleepStarted) {}
        else:
            Print("Flow checks FAILED: OFF comparison still sleeps before MoveTo.")
            return false
        CanceledSleep := flow_recording_target{}
        race:
            Shared.MoveChecked(CanceledSleep, 0, vector3{}, vector3{Up := 40.0}, Region, WithSleep, true)
            Sleep(0.02)
        Sleep(0.12)
        if(CanceledSleep.Destinations.Length <> 0):
            Print("Flow checks FAILED: canceled sleep issued a MoveTo.")
            return false
        CanceledMove := flow_recording_target{SuspendMoves := true}
        race:
            Shared.MoveChecked(CanceledMove, 0, vector3{}, vector3{Up := 350.0}, Region, Config, true)
            Sleep(0.02)
        Sleep(0.05)
        if(CanceledMove.Positions[0].LengthSquared() = 0.0, CanceledMove.Destinations.Length = 1) {}
        else:
            Print("Flow checks FAILED: canceled MoveTo survived.")
            return false
    else:
        return false
    Print("Flow checks PASSED: bounds/curves, streams, concurrency, timing, no-op, restart, Sleep A/B ordering and cancellation. Visual acceptance remains manual.")
    true

CheckFlowGeometry()<transacts> : logic =
    Config := SanitizeFlow(flow_configuration{Speed := 0.0, SpreadDegrees := 999.0, Persistence := 3.0})
    if(Config.Speed <> 10.0 or Config.SpreadDegrees <> 180.0 or Config.Persistence <> 0.95):
        return false
    Box := target_spawn_box_bounds{Center := vector3{}, Width := 1000.0, Height := 600.0, Depth := 30.0}
    for(Space : array{flow_space.ViewPlane, flow_space.GroundPlane}):
        C := flow_configuration{Space := Space, Seed := 1234, PlayerClearance := 0.0}
        if(Region := BuildFlowRegion[Box, C, vector3{}]):
            State := MakeFlowState(C, 0, vector3{})
            var Last : ?flow_curve = false
            for(I := 0..299):
                if(Curve := PlanFlowCurve(State, Region, C, array{})?):
                    if(Previous := Last?):
                        if(Distance(Previous.C, Curve.A) > 0.00001):
                            return false
                        if(Distance(Previous.C - Previous.B, Curve.B - Curve.A) > 0.00001):
                            return false
                    for(J := 0..20):
                        P := FlowPoint(Curve, (J * 1.0) / 20.0)
                        if(Abs(P.Left) > Region.Half.Left + 0.00001):
                            return false
                        if(Abs(P.Up) > Region.Half.Up + 0.00001):
                            return false
                    set Last = option{Curve}
                else:
                    return false
        else:
            return false
    # Endpoint-only tests would miss this forbidden crossing.
    Disc := array{flow_disc{Center := vector3{}, Radius := 100.0}}
    if(FlowSegmentClear(vector3{Left := -200.0}, vector3{Left := 200.0}, Disc)?):
        return false
    if(not FlowSegmentClear(vector3{Left := -200.0, Up := 101.0}, vector3{Left := 200.0, Up := 101.0}, Disc)?):
        return false
    if(FlowCurveClear(flow_curve{A := vector3{}, B := vector3{Left := 300.0}, C := vector3{Left := 400.0}}, Disc)?):
        return false
    # Straight degeneration must retain its reversal extremum and avoid short subdivision.
    Reversal := flow_curve{A := vector3{}, B := vector3{Up := 100.0}, C := vector3{}}
    Samples := FlowSamples(Reversal, 350.0, false)
    if(Samples.Length = 2, Abs(Samples[0].Up - 50.0) < 0.001, Samples[1].Up = 0.0) {}
    else:
        return false
    true
