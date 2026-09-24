using { /Verse.org/Random }
using { /Verse.org/SpatialMath }
using { GameData.ScenarioData.Definitions }

waypoint_region := struct:
    Center : vector3
    HalfExtent : vector3

waypoint_cursor := struct:
    Index : int = 0
    Step : int = 1

waypoint_leg := struct:
    Destination : vector3
    Cursor : waypoint_cursor

WaypointArrivalTolerance : float = 0.5

ValidateWaypointConfiguration(Config : waypoint_configuration)<transacts><decides> : void =
    Config.Speed.IsFinite[]
    Config.Speed > 0.0
    Config.EdgePadding.IsFinite[]
    Config.EdgePadding >= 0.0
    Config.JitterFraction.IsFinite[]
    Config.JitterFraction >= 0.0
    Config.JitterFraction <= 1.0
    Config.MinLegDistance.IsFinite[]
    Config.MinLegDistance >= 1.0
    Config.Points.Length >= 2
    for(Point : Config.Points):
        Point.IsFinite[]
        Abs(Point.Left) <= 1.0
        Abs(Point.Up) <= 1.0
        Abs(Point.Forward) <= 1.0

BuildWaypointRegion(Bounds : target_spawn_box_bounds, Config : waypoint_configuration, InitialPosition : vector3)<transacts><decides> : waypoint_region =
    InitialPosition.IsFinite[]
    Bounds.Center.IsFinite[]
    Bounds.Width.IsFinite[]
    Bounds.Height.IsFinite[]
    Bounds.Depth.IsFinite[]
    LeftExtent := Bounds.Width * 0.5 - Config.EdgePadding
    LeftExtent > 0.0

    var Center : vector3 = Bounds.Center
    var HalfExtent : vector3 = vector3{Left := LeftExtent}
    case(Config.Space):
        waypoint_space.ViewPlane =>
            UpExtent := Bounds.Height * 0.5 - Config.EdgePadding
            UpExtent > 0.0
            set HalfExtent.Up = UpExtent
            set Center.Forward = InitialPosition.Forward
        waypoint_space.GroundPlane =>
            ForwardExtent := Bounds.Depth * 0.5 - Config.EdgePadding
            ForwardExtent > 0.0
            set HalfExtent.Forward = ForwardExtent
            set Center.Up = InitialPosition.Up
        waypoint_space.Volume =>
            UpExtent := Bounds.Height * 0.5 - Config.EdgePadding
            ForwardExtent := Bounds.Depth * 0.5 - Config.EdgePadding
            UpExtent > 0.0
            ForwardExtent > 0.0
            set HalfExtent.Up = UpExtent
            set HalfExtent.Forward = ForwardExtent

    # Also reject finite inputs whose derived endpoints overflow.
    (Center - HalfExtent).IsFinite[]
    (Center + HalfExtent).IsFinite[]
    waypoint_region{Center := Center, HalfExtent := HalfExtent}

ProjectIntoWaypointRegion(Position : vector3, Region : waypoint_region)<transacts> : vector3 =
    Low := Region.Center - Region.HalfExtent
    High := Region.Center + Region.HalfExtent
    vector3{
        Left := Clamp(Position.Left, Low.Left, High.Left),
        Up := Clamp(Position.Up, Low.Up, High.Up),
        Forward := Clamp(Position.Forward, Low.Forward, High.Forward)
    }

SampleWaypointAxis(Coordinate : float, Jitter : float)<transacts> : float =
    # Sample the clipped interval; clamping an already sampled value piles up at walls.
    GetRandomFloat(Max(-1.0, Coordinate - Jitter), Min(1.0, Coordinate + Jitter))

SampleWaypoint(Point : vector3, Region : waypoint_region, Jitter : float)<transacts> : vector3 =
    vector3{
        Left := Region.Center.Left + Region.HalfExtent.Left * SampleWaypointAxis(Point.Left, Jitter),
        Up := Region.Center.Up + Region.HalfExtent.Up * SampleWaypointAxis(Point.Up, Jitter),
        Forward := Region.Center.Forward + Region.HalfExtent.Forward * SampleWaypointAxis(Point.Forward, Jitter)
    }

FindWaypointDestination(Point : vector3, Position : vector3, Region : waypoint_region, Config : waypoint_configuration)<transacts> : ?vector3 =
    # Bounded sampling also handles duplicates and collapsed projected routes.
    LastAttempt := if(Config.JitterFraction > 0.0) then 7 else 0
    for(Attempt := 0..LastAttempt):
        Candidate := SampleWaypoint(Point, Region, Config.JitterFraction)
        LegDistance := Distance(Position, Candidate)
        if(LegDistance.IsFinite[], LegDistance >= Config.MinLegDistance):
            return option{Candidate}
    false

AdvanceWaypointCursor(Cursor : waypoint_cursor, Count : int, Traversal : waypoint_traversal)<transacts> : waypoint_cursor =
    if(Count < 2):
        return waypoint_cursor{}
    if(Traversal = waypoint_traversal.PingPong):
        NextIndex := Cursor.Index + Cursor.Step
        if(NextIndex >= Count):
            waypoint_cursor{Index := Count - 2, Step := -1}
        else if(NextIndex < 0):
            waypoint_cursor{Index := 1, Step := 1}
        else:
            waypoint_cursor{Index := NextIndex, Step := Cursor.Step}
    else:
        waypoint_cursor{Index := if(Cursor.Index + 1 >= Count) then 0 else Cursor.Index + 1}

MakeWaypointStart(Config : waypoint_configuration)<transacts> : waypoint_cursor =
    if(Config.RandomStart?, Config.Traversal <> waypoint_traversal.Random):
        Index := GetRandomInt(0, Config.Points.Length - 1)
        Step := if(Config.Traversal = waypoint_traversal.PingPong, GetRandomInt(0, 1) = 0) then -1 else 1
        waypoint_cursor{Index := Index, Step := Step}
    else:
        waypoint_cursor{}

SelectWaypointLeg(Position : vector3, Region : waypoint_region, Config : waypoint_configuration, Cursor : waypoint_cursor, PreviousIndex : int)<transacts> : ?waypoint_leg =
    if(Config.Traversal = waypoint_traversal.Random):
        # Choose among usable destinations, excluding the previous waypoint identity.
        Candidates := for(Index -> Point : Config.Points, Index <> PreviousIndex,
            Destination := FindWaypointDestination(Point, Position, Region, Config)?):
                waypoint_leg{Destination := Destination, Cursor := waypoint_cursor{Index := Index}}
        if(Candidates.Length > 0):
            return option{Candidates[GetRandomInt(0, Candidates.Length - 1)]}
        return false

    var CandidateCursor : waypoint_cursor = Cursor
    # A full ping-pong cycle visits every point even when some entries are too close.
    for(Attempt := 0..(Config.Points.Length * 2 - 1)):
        if:
            Point := Config.Points[CandidateCursor.Index]
            Destination := FindWaypointDestination(Point, Position, Region, Config)?
        then:
            return option{waypoint_leg{Destination := Destination, Cursor := CandidateCursor}}
        set CandidateCursor = AdvanceWaypointCursor(CandidateCursor, Config.Points.Length, Config.Traversal)
    false
