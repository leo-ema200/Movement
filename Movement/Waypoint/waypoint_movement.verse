using { /Verse.org/Simulation }
using { /Verse.org/SpatialMath }
using { GameData.ScenarioData.Definitions }

waypoint_movement<public> := class(movement_behavior):
    Configuration<public> : waypoint_configuration = waypoint_configuration{}

    Run<override>(TargetObject : target, TargetIndex : int, Bounds : target_spawn_bounds)<suspends> : void =
        if:
            ValidateWaypointConfiguration[Configuration]
            BoxBounds := target_spawn_box_bounds[Bounds]
            InitialPosition := TargetObject.GetTargetPositions()[TargetIndex]
            Region := BuildWaypointRegion[BoxBounds, Configuration, InitialPosition]
        then:
            # All mutable state belongs to this invocation, never to the shared behavior.
            var CurrentPosition : vector3 = InitialPosition
            var Cursor : waypoint_cursor = MakeWaypointStart(Configuration)
            var PreviousIndex : int = -1

            EntryPosition := ProjectIntoWaypointRegion(CurrentPosition, Region)
            if(Distance(CurrentPosition, EntryPosition) > 0.0):
                EntryResult := MoveAndRead(TargetObject, TargetIndex, CurrentPosition, EntryPosition)
                if(ReachedPosition := EntryResult?):
                    set CurrentPosition = ReachedPosition
                else:
                    return

            loop:
                if(Leg := SelectWaypointLeg(CurrentPosition, Region, Configuration, Cursor, PreviousIndex)?):
                    MoveResult := MoveAndRead(TargetObject, TargetIndex, CurrentPosition, Leg.Destination)
                    if(ReachedPosition := MoveResult?):
                        set CurrentPosition = ReachedPosition
                        set PreviousIndex = Leg.Cursor.Index
                        set Cursor = AdvanceWaypointCursor(Leg.Cursor, Configuration.Points.Length, Configuration.Traversal)
                    else:
                        return
                else:
                    # No useful leg: stop instead of busy-looping on invalid/nearby points.
                    return

    MoveAndRead(TargetObject : target, TargetIndex : int, From : vector3, Destination : vector3)<suspends> : ?vector3 =
        TravelDistance := Distance(From, Destination)
        TravelTime := CalculateMoveTime(TravelDistance, Configuration.Speed)
        if(TravelTime.IsFinite[], TravelTime > 0.0):
            StartedAt := GetSimulationElapsedTime()
            TargetObject.MoveTo(TargetIndex, Destination, TravelTime)
            # The interface returns void. Read actual arrival instead of assuming success.
            if:
                Actual := TargetObject.GetTargetPositions()[TargetIndex]
                Actual.IsFinite[]
                Distance(Actual, Destination) <= WaypointArrivalTolerance
            then:
                # Defensive yield only for implementations that complete without suspending.
                if(GetSimulationElapsedTime() <= StartedAt):
                    Sleep(0.0)
                return option{Actual}
        false
