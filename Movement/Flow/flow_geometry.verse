using { /Verse.org/SpatialMath }
using { /Verse.org/Random }
using { GameData.ScenarioData.Definitions }

flow_region := struct:
    Origin : vector3
    Half : vector3
    Space : flow_space

flow_curve := struct:
    A : vector3
    B : vector3
    C : vector3

flow_disc := struct:
    Center : vector3
    Radius : float

# Created INSIDE Run. No mutable member of flow_movement/configuration.
flow_state := class:
    var RandomState : int = 1
    var Trend : vector3 = vector3{Up := 1.0}
    var Offset : float = 0.0
    var Side : float = 1.0
    var Previous : vector3 = vector3{}
    var Control : vector3 = vector3{}

    Next()<transacts> : float =
        if(Value := Mod[RandomState * 48271, 2147483647]):
            set RandomState = Value
        (RandomState * 1.0) / 2147483647.0

FlowFinite<public>(Value : float, Low : float, High : float, Fallback : float)<transacts> : float =
    if(Value.IsFinite[]) then Clamp(Value, Low, High) else Fallback

SanitizeFlow(Config : flow_configuration)<transacts> : flow_configuration =
    flow_configuration{
        Speed := FlowFinite(Config.Speed, 10.0, 2000.0, 350.0),
        EdgePadding := FlowFinite(Config.EdgePadding, 0.0, 1000000.0, 50.0),
        Space := Config.Space,
        HeadingDegrees := FlowFinite(Config.HeadingDegrees, 0.0, 360.0, 90.0),
        SpreadDegrees := FlowFinite(Config.SpreadDegrees, 0.0, 180.0, 35.0),
        TurnDistance := FlowFinite(Config.TurnDistance, 25.0, 2000.0, 300.0),
        Persistence := FlowFinite(Config.Persistence, 0.0, 0.95, 0.25),
        SideSwitchChance := FlowFinite(Config.SideSwitchChance, 0.0, 1.0, 0.65),
        Randomness := FlowFinite(Config.Randomness, 0.0, 1.0, 0.8),
        Seed := Clamp(Config.Seed, 0, 2147483646),
        PlayerClearance := FlowFinite(Config.PlayerClearance, 0.0, 2000.0, 150.0),
        ExperimentalSleep := Config.ExperimentalSleep
    }

MakeFlowState(Config : flow_configuration, Index : int, Start : vector3)<transacts> : flow_state =
    Seed := if(Config.Seed = 0) then GetRandomInt(1, 2147483646) else Config.Seed
    Mixed := if(Value := Mod[Seed + Abs(Index) * 104729, 2147483646]) then Value + 1 else 1
    Angle := DegreesToRadians(Config.HeadingDegrees)
    State := flow_state{
        RandomState := Mixed, Trend := vector3{Left := Cos(Angle), Up := Sin(Angle)},
        Previous := Start, Control := Start
    }
    if(Config.Randomness > 0.0):
        InitialSide := State.Next()
        if(InitialSide < 0.5):
            set State.Side = -1.0
        set State.Offset = (State.Next() * 2.0 - 1.0) * Config.SpreadDegrees * Config.Randomness
    State

BuildFlowRegion(Box : target_spawn_box_bounds, Config : flow_configuration, Start : vector3)<transacts><decides> : flow_region =
    Start.IsFinite[]
    Box.Center.IsFinite[]
    Box.Width.IsFinite[]
    Box.Height.IsFinite[]
    Box.Depth.IsFinite[]
    Box.Width >= 2.0
    Box.Height >= 2.0
    Box.Depth >= 2.0
    # Cannot promise containment for a spawn already outside the raw box.
    Abs(Start.Left - Box.Center.Left) <= Box.Width * 0.5
    Abs(Start.Up - Box.Center.Up) <= Box.Height * 0.5
    Abs(Start.Forward - Box.Center.Forward) <= Box.Depth * 0.5
    SecondSize := if(Config.Space = flow_space.ViewPlane) then Box.Height else Box.Depth
    Half := vector3{
        Left := Box.Width * 0.5 - Min(Config.EdgePadding, Box.Width * 0.45),
        Up := SecondSize * 0.5 - Min(Config.EdgePadding, SecondSize * 0.45)
    }
    Origin := if(Config.Space = flow_space.ViewPlane):
        vector3{Left := Box.Center.Left, Up := Box.Center.Up, Forward := Start.Forward}
    else:
        vector3{Left := Box.Center.Left, Up := Start.Up, Forward := Box.Center.Forward}
    (Origin + vector3{Left := Half.Left, Up := Half.Up, Forward := Half.Up}).IsFinite[]
    (Origin - vector3{Left := Half.Left, Up := Half.Up, Forward := Half.Up}).IsFinite[]
    flow_region{Origin := Origin, Half := Half, Space := Config.Space}

FlowLocal(P : vector3, Region : flow_region)<transacts> : vector3 =
    Delta := P - Region.Origin
    vector3{Left := Delta.Left, Up := if(Region.Space = flow_space.ViewPlane) then Delta.Up else Delta.Forward}

FlowWorld(P : vector3, Region : flow_region)<transacts> : vector3 =
    Region.Origin + if(Region.Space = flow_space.ViewPlane):
        vector3{Left := P.Left, Up := P.Up}
    else:
        vector3{Left := P.Left, Forward := P.Up}

FlowRotate(V : vector3, Degrees : float)<transacts> : vector3 =
    R := DegreesToRadians(Degrees)
    vector3{Left := V.Left * Cos(R) - V.Up * Sin(R), Up := V.Left * Sin(R) + V.Up * Cos(R)}

FlowPoint(Curve : flow_curve, T : float)<transacts> : vector3 =
    Curve.A * ((1.0 - T) * (1.0 - T)) + Curve.B * (2.0 * T * (1.0 - T)) + Curve.C * (T * T)

FlowSegmentClear(A : vector3, B : vector3, Discs : []flow_disc)<transacts> : logic =
    V := B - A
    for(Disc : Discs):
        T := if(V.LengthSquared() > 0.000001) then Clamp(DotProduct(Disc.Center - A, V) / V.LengthSquared(), 0.0, 1.0) else 0.0
        if(Distance(A + V * T, Disc.Center) <= Disc.Radius):
            return false
    true

FlowCurveClear(Curve : flow_curve, Discs : []flow_disc)<transacts> : logic =
    # Sufficient convex-hull certificate: all controls outside the same tangent half-plane.
    # Conservative on purpose; checking endpoints alone would cut through a player.
    for(Disc : Discs):
        if(Distance(Curve.A, Disc.Center) <= Disc.Radius):
            return false
        Normal := (Curve.A - Disc.Center).MakeUnitVector()
        for(P : array{Curve.A, Curve.B, Curve.C}):
            if(DotProduct(P - Disc.Center, Normal) <= Disc.Radius):
                return false
    true

PlanFlowCurve(State : flow_state, Region : flow_region, Config : flow_configuration, Discs : []flow_disc)<transacts> : ?flow_curve =
    Switch := if(Config.Randomness > 0.0) then State.Next() else 0.5
    if(Switch < Config.SideSwitchChance):
        set State.Side *= -1.0
    Magnitude := Config.SpreadDegrees * (1.0 - Config.Randomness * State.Next())
    Desired := State.Side * Magnitude
    set State.Offset = State.Offset * Config.Persistence + Desired * (1.0 - Config.Persistence)
    NominalLength := Config.TurnDistance * (1.0 + Config.Randomness * (State.Next() - 0.5))
    BaseDirection := FlowRotate(State.Trend, State.Offset)
    A := (State.Previous + State.Control) * 0.5

    # The first candidate is the intended organic decision. Other candidates only avoid
    # exclusion zones/degenerate folds; there is no rejection loop without an upper bound.
    for(Attempt := 0..12):
        FanIndex := if(Value := Ceil[(Attempt * 1.0) / 2.0]) then Value else 0
        Fan := FanIndex * 30.0
        SignedFan := if(Discs.Length = 0, Config.SpreadDegrees = 0.0) then 0.0 else if(Mod[Attempt, 2] = 0) then Fan else -Fan
        Direction := FlowRotate(BaseDirection, SignedFan)
        LeftLimit := if(Abs(Direction.Left) > 0.000001) then Region.Half.Left * 0.8 / Abs(Direction.Left) else NominalLength
        UpLimit := if(Abs(Direction.Up) > 0.000001) then Region.Half.Up * 0.8 / Abs(Direction.Up) else NominalLength
        # On a degenerate fold, shorten a strict-axis leg instead of inventing lateral drift.
        LengthScale := if(Discs.Length = 0, Config.SpreadDegrees = 0.0, Attempt > 0) then 0.5 else 1.0
        LegLength := Min(NominalLength, Min(LeftLimit, UpLimit)) * LengthScale
        Raw := State.Control + Direction * LegLength
        var Next : vector3 = Raw
        var Trend : vector3 = State.Trend
        var Reflections : int = 0
        # Fold the CONTROL polygon before smoothing. Never clamp rendered positions.
        if(Abs(Raw.Left) > Region.Half.Left):
            set Next.Left = if(Raw.Left > 0.0) then 2.0 * Region.Half.Left - Raw.Left else -2.0 * Region.Half.Left - Raw.Left
            set Trend.Left *= -1.0
            set Reflections += 1
        if(Abs(Raw.Up) > Region.Half.Up):
            set Next.Up = if(Raw.Up > 0.0) then 2.0 * Region.Half.Up - Raw.Up else -2.0 * Region.Half.Up - Raw.Up
            set Trend.Up *= -1.0
            set Reflections += 1
        Curve := flow_curve{A := A, B := State.Control, C := (State.Control + Next) * 0.5}
        UsefulDistance := Min(0.05, Min(Region.Half.Left, Region.Half.Up) * 0.01)
        if(Distance(State.Control, Next) > UsefulDistance, FlowCurveClear(Curve, Discs)?):
            set State.Previous = State.Control
            set State.Control = Next
            set State.Trend = Trend
            if(Mod[Reflections, 2] = 1):
                set State.Offset *= -1.0
                set State.Side *= -1.0
            return option{Curve}
    false

FlowIsCurved(Curve : flow_curve)<transacts> : logic =
    V := Curve.B - Curve.A
    W := Curve.C - Curve.B
    logic{Abs(V.Left * W.Up - V.Up * W.Left) > 0.0001}

FlowSamples(Curve : flow_curve, Speed : float, Protected : logic)<transacts> : []vector3 =
    if(not FlowIsCurved(Curve)?, not Protected?):
        # Preserve the exact extremum of a collinear reversal, otherwise one long MoveTo.
        V := Curve.B - Curve.A
        W := Curve.C - Curve.B
        if(DotProduct(V, W) < 0.0):
            Total := V.Length() + W.Length()
            return array{FlowPoint(Curve, V.Length() / Total), Curve.C}
        return array{Curve.C}
    MaximumDerivative := 2.0 * Max(Distance(Curve.A, Curve.B), Distance(Curve.B, Curve.C))
    Bend := (Curve.A - Curve.B * 2.0 + Curve.C).Length()
    # <= 0.12 s movement per chord; quadratic chord error <= 2 cm.
    Needed := Max(MaximumDerivative / (Speed * 0.12), Sqrt(Bend / 8.0))
    Count := if(N := Ceil[Needed]) then Clamp(N, 1, 4096) else 1
    for(I := 1..Count):
        FlowPoint(Curve, (I * 1.0) / (Count * 1.0))
