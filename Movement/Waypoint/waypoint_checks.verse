using { /Verse.org/Simulation }
using { /Verse.org/SpatialMath }
using { GameData.ScenarioData.Definitions }

# Contract double: records actual calls; deliberately stops arriving after MaxMoves.
# Used only by the optional preview's checks, never by the production behavior.
waypoint_recording_target := class(target):
    var Positions : []vector3 = array{vector3{}}
    var Destinations : []vector3 = array{}
    var Durations : []float = array{}
    var Indices : []int = array{}
    MaxMoves : int = 6
    SuspendMoves : logic = false

    GetTargetPositions<override>()<transacts> : []vector3 = Positions
    GetTargetSpacing<override>()<transacts> : float = 0.0

    MoveTo<override>(TargetIndex : int, NewPosition : vector3, OverTime : float)<suspends> : void =
        set Destinations += array{NewPosition}
        set Durations += array{OverTime}
        set Indices += array{TargetIndex}
        if(SuspendMoves?):
            Sleep(0.1)
        if(Destinations.Length <= MaxMoves):
            if(set Positions[TargetIndex] = NewPosition) {}

RunWaypointChecks<public>()<suspends> : logic =
    Bounds := target_spawn_box_bounds{
        Center := vector3{}, Width := 1000.0, Height := 800.0, Depth := 600.0
    }
    Config := waypoint_configuration{
        Traversal := waypoint_traversal.Loop, RandomStart := false, JitterFraction := 0.0,
        Points := array{
            vector3{Left := -0.8}, vector3{Up := 0.8}, vector3{Left := 0.8}
        }
    }
    Behavior := waypoint_movement{Configuration := Config}

    # Golden route: actual Run must visit specific destinations at distance / speed.
    Recorder := waypoint_recording_target{}
    Behavior.Run(Recorder, 0, Bounds)
    if:
        Recorder.Destinations.Length = 7
        First := Recorder.Destinations[0]
        Second := Recorder.Destinations[1]
        Third := Recorder.Destinations[2]
        Fourth := Recorder.Destinations[3]
        Distance(First, vector3{Left := -360.0}) < 0.001
        Distance(Second, vector3{Up := 280.0}) < 0.001
        Distance(Third, vector3{Left := 360.0}) < 0.001
        Distance(Fourth, First) < 0.001
        Abs(Recorder.Durations[0] - 0.6) < 0.001
        Abs(Recorder.Durations[1] - Distance(First, Second) / 600.0) < 0.001
    then {}
    else:
        Print("Waypoint checks FAILED: route, timing, or failed-arrival termination.")
        return false

    # Restart must use the target's new pose, including its preserved plane coordinate.
    set Recorder.Positions = array{vector3{Left := 100.0, Forward := 75.0}}
    set Recorder.Destinations = array{}
    set Recorder.Durations = array{}
    Behavior.Run(Recorder, 0, Bounds)
    if:
        RestartFirst := Recorder.Destinations[0]
        RestartFirst.Forward = 75.0
        Abs(Recorder.Durations[0] - 460.0 / 600.0) < 0.001
    then {}
    else:
        Print("Waypoint checks FAILED: restart from actual pose.")
        return false

    # Same behavior concurrently: one run must not advance the other's route cursor.
    TargetA := waypoint_recording_target{Positions := array{vector3{Forward := 10.0}}}
    TargetB := waypoint_recording_target{Positions := array{vector3{}, vector3{Forward := 90.0}}}
    sync:
        Behavior.Run(TargetA, 0, Bounds)
        Behavior.Run(TargetB, 1, Bounds)
    if:
        TargetA.Destinations.Length = 7
        TargetB.Destinations.Length = 7
        TargetA.Destinations[0].Forward = 10.0
        TargetB.Destinations[0].Forward = 90.0
        TargetA.Destinations[1].Up = 280.0
        TargetB.Destinations[1].Up = 280.0
        TargetB.Indices[0] = 1
        TargetB.Indices[6] = 1
    then {}
    else:
        Print("Waypoint checks FAILED: concurrent state or TargetIndex.")
        return false

    # A no-op implementation must produce one attempt, not a hot loop.
    NoOp := waypoint_recording_target{MaxMoves := 0}
    Behavior.Run(NoOp, 0, Bounds)
    if(NoOp.Destinations.Length <> 1):
        Print("Waypoint checks FAILED: no-op MoveTo.")
        return false

    # Invalid index, unsupported bounds, invalid config and collapsed routes do not move.
    Invalid := waypoint_recording_target{}
    Behavior.Run(Invalid, 3, Bounds)
    Behavior.Run(Invalid, 0, target_spawn_radial_bounds{})
    waypoint_movement{Configuration := waypoint_configuration{Speed := 0.0}}.Run(Invalid, 0, Bounds)
    waypoint_movement{Configuration := waypoint_configuration{EdgePadding := 500.0}}.Run(Invalid, 0, Bounds)
    waypoint_movement{Configuration := waypoint_configuration{
        Points := array{vector3{}, vector3{}}, JitterFraction := 0.0
    }}.Run(Invalid, 0, Bounds)
    if(Invalid.Destinations.Length <> 0):
        Print("Waypoint checks FAILED: invalid/degenerate input.")
        return false

    # Outside start recovers continuously to the nearest padded boundary.
    Outside := waypoint_recording_target{Positions := array{vector3{Left := 700.0}}}
    Behavior.Run(Outside, 0, Bounds)
    if:
        Outside.Destinations[0].Left = 450.0
        Abs(Outside.Durations[0] - 250.0 / 600.0) < 0.001
    then {}
    else:
        Print("Waypoint checks FAILED: bounds entry.")
        return false

    # Cancellation is owned by the caller. No unstructured task may survive Run.
    Canceled := waypoint_recording_target{SuspendMoves := true}
    race:
        Behavior.Run(Canceled, 0, Bounds)
        Sleep(0.02)
    Sleep(0.15)
    if(Canceled.Destinations.Length <> 1):
        Print("Waypoint checks FAILED: cancellation call count.")
        return false
    if(Position := Canceled.Positions[0], Position.LengthSquared() > 0.0):
        Print("Waypoint checks FAILED: movement survived cancellation.")
        return false

    if(not CheckWaypointGeometry(Bounds)?):
        Print("Waypoint checks FAILED: projection, traversal, or random bounds.")
        return false
    Print("Waypoint checks PASSED: route/timing, restart, concurrency, no-op, invalid inputs, entry, cancellation, geometry.")
    true

CheckWaypointGeometry(Bounds : target_spawn_box_bounds)<transacts> : logic =
    # Expected PingPong sequence is independent of the implementation's recurrence.
    Expected := array{0, 1, 2, 1, 0, 1, 2, 1}
    var Cursor : waypoint_cursor = waypoint_cursor{}
    for(Index : Expected):
        if(Cursor.Index <> Index):
            return false
        set Cursor = AdvanceWaypointCursor(Cursor, 3, waypoint_traversal.PingPong)

    for(Space : array{waypoint_space.ViewPlane, waypoint_space.GroundPlane, waypoint_space.Volume}):
        Config := waypoint_configuration{Space := Space, JitterFraction := 1.0}
        if(Region := BuildWaypointRegion[Bounds, Config, vector3{Up := 25.0, Forward := 30.0}]):
            Low := Region.Center - Region.HalfExtent
            High := Region.Center + Region.HalfExtent
            for(Attempt := 0..99):
                Position := SampleWaypoint(vector3{Left := 1.0, Up := -1.0, Forward := 1.0}, Region, 1.0)
                if:
                    Position.Left >= Low.Left
                    Position.Left <= High.Left
                    Position.Up >= Low.Up
                    Position.Up <= High.Up
                    Position.Forward >= Low.Forward
                    Position.Forward <= High.Forward
                then {}
                else:
                    return false
                if(Space = waypoint_space.ViewPlane, Position.Forward <> 30.0):
                    return false
                if(Space = waypoint_space.GroundPlane, Position.Up <> 25.0):
                    return false
            # Random excludes the previous waypoint; exact points make this check deterministic.
            SelectionConfig := waypoint_configuration{Space := Space, JitterFraction := 0.0}
            if(Leg := SelectWaypointLeg(Region.Center, Region, SelectionConfig, waypoint_cursor{}, 1)?):
                if(Leg.Cursor.Index = 1):
                    return false
            else:
                return false
        else:
            return false
    true
