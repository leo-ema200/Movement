using { /Verse.org/Simulation }
using { /Verse.org/SpatialMath }
using { /Fortnite.com/Playspaces }
using { /Fortnite.com/Characters }
using { /UnrealEngine.com/Temporary }
using { GameData.ScenarioData.Definitions }

flow_move_result := enum:
    Arrived
    Blocked
    Failed

flow_movement<public> := class(movement_behavior):
    Configuration<public> : flow_configuration = flow_configuration{}
    # Inject once on construction (e.g. creative_device.GetPlayspace()).
    # Required while PlayerClearance > 0; never assume the player is at the box center.
    Playspace<public> : ?fort_playspace = false

    ProtectedDiscs(Region : flow_region, Radius : float)<transacts> : []flow_disc =
        var Result : []flow_disc = array{}
        if(Radius > 0.0, World := Playspace?):
            for(Player : World.GetPlayers(), Character := Player.GetFortCharacter[], Character.IsActive[]):
                P := SpatialMath.FromVector3(Character.GetTransform().Translation)
                # Ground uses a cylinder regardless of player height; view uses a sphere.
                Separation := if(Region.Space = flow_space.ViewPlane) then Abs(P.Forward - Region.Origin.Forward) else 0.0
                if(Separation < Radius):
                    set Result += array{flow_disc{
                        Center := FlowLocal(P, Region), Radius := Sqrt(Radius * Radius - Separation * Separation)
                    }}
        Result

    Run<override>(TargetObject : target, TargetIndex : int, Bounds : target_spawn_bounds)<suspends> : void =
        Config := SanitizeFlow(Configuration)
        if(Config.PlayerClearance > 0.0, not Playspace?):
            Print("Flow: supply Playspace for player protection, or explicitly set PlayerClearance = 0.")
            return
        if:
            Box := target_spawn_box_bounds[Bounds]
            Start := TargetObject.GetTargetPositions()[TargetIndex]
            Region := BuildFlowRegion[Box, Config, Start]
        then:
            var Position : vector3 = FlowLocal(Start, Region)
            # One continuous straight entry when the spawn lies in raw bounds but in padding.
            Entry := vector3{
                Left := Clamp(Position.Left, -Region.Half.Left, Region.Half.Left),
                Up := Clamp(Position.Up, -Region.Half.Up, Region.Half.Up)
            }
            if(Distance(Position, Entry) > 0.01):
                EntryStart := Position
                # Protected entry also samples players between short physical moves.
                Required := if(Config.PlayerClearance > 0.0) then Distance(Position, Entry) / (Config.Speed * 0.12) else 1.0
                EntryCount := if(N := Ceil[Required]) then Max(1, N) else 1
                for(I := 1..EntryCount):
                    EntryStep := EntryStart + (Entry - EntryStart) * ((I * 1.0) / (EntryCount * 1.0))
                    Result := MoveChecked(TargetObject, TargetIndex, Position, EntryStep, Region, Config, false)
                    if(Result <> flow_move_result.Arrived):
                        Print("Flow: padded entry blocked or adapter did not arrive.")
                        return
                    set Position = EntryStep
            State := MakeFlowState(Config, TargetIndex, Position)
            loop:
                Discs := ProtectedDiscs(Region, Config.PlayerClearance)
                # Consume the local random decision even if every candidate is blocked.
                Planned := PlanFlowCurve(State, Region, Config, Discs)
                if(Curve := Planned?):
                    Samples := FlowSamples(Curve, Config.Speed, logic{Config.PlayerClearance > 0.0})
                    var Interrupted : logic = false
                    var Moved : logic = false
                    for(Destination : Samples, not Interrupted?):
                        if(Distance(Position, Destination) > 0.01):
                            Result := MoveChecked(TargetObject, TargetIndex, Position, Destination, Region, Config, FlowIsCurved(Curve))
                            case(Result):
                                flow_move_result.Arrived =>
                                    set Position = Destination
                                    set Moved = true
                                flow_move_result.Blocked =>
                                    set Interrupted = true
                                flow_move_result.Failed =>
                                    Print("Flow: target did not arrive, index disappeared, or another owner moved it.")
                                    return
                    if(Interrupted?):
                        # Moving obstacle invalidated the plan. Restart from the real current pose,
                        # retaining the same Run's random stream. Never teleport through an obstacle.
                        set State.Previous = Position
                        set State.Control = Position
                        Sleep(0.1)
                    else if(not Moved?):
                        Sleep(0.0)
                else:
                    # A player may cover the available corridor. Bounded retries and cooperative wait.
                    set State.Previous = Position
                    set State.Control = Position
                    Sleep(0.1)
        else:
            Print("Flow: requires finite Box bounds >= 2 cm on all axes and a valid target inside the raw box.")

    MoveChecked(TargetObject : target, TargetIndex : int, From : vector3, To : vector3, Region : flow_region, Config : flow_configuration, Curved : logic)<suspends> : flow_move_result =
        TravelTime := Distance(From, To) / Config.Speed
        if(not TravelTime.IsFinite[]):
            return flow_move_result.Failed
        if(TravelTime <= 0.0):
            return flow_move_result.Failed
        if(Config.ExperimentalSleep?, Curved?):
            # Deliberate A/B experiment, BEFORE each short MoveTo building a curve.
            Sleep(0.1)
        # Re-read AFTER Sleep: neither player motion nor external target ownership is ignored.
        if:
            Actual := TargetObject.GetTargetPositions()[TargetIndex]
            Actual.IsFinite[]
            Distance(Actual, FlowWorld(From, Region)) <= 0.5
        then:
            if(not FlowSegmentClear(From, To, ProtectedDiscs(Region, Config.PlayerClearance))?):
                return flow_move_result.Blocked
            Started := GetSimulationElapsedTime()
            TargetObject.MoveTo(TargetIndex, FlowWorld(To, Region), TravelTime)
            if:
                Reached := TargetObject.GetTargetPositions()[TargetIndex]
                Reached.IsFinite[]
                Distance(Reached, FlowWorld(To, Region)) <= 0.5
            then:
                if(GetSimulationElapsedTime() <= Started):
                    Sleep(0.0)
                return flow_move_result.Arrived
        flow_move_result.Failed
