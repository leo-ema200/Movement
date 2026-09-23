using { /Verse.org/SpatialMath }
using { /Verse.org/Random }
using {GameData.ScenarioData.Definitions}

linear_movement<public> := class(movement_behavior):

    Configuration<public> : linear_movement_configuration = linear_movement_configuration{}

    Run<override>(TargetObject : target, TargetIndex : int, Bounds : target_spawn_bounds)<suspends> : void =

        # Linear V1 actualmente trabaja con Box Bounds.
        if:
            BoxBounds := target_spawn_box_bounds[Bounds]
            CurrentPosition := TargetObject.GetTargetPositions()[TargetIndex]
        then:
            RunBoxMovement(
                TargetObject,
                TargetIndex,
                BoxBounds,
                CurrentPosition
            )

    RunBoxMovement(TargetObject : target, TargetIndex : int, Bounds : target_spawn_box_bounds, InitialPosition : vector3)<suspends> : void =

        if(Configuration.Speed <= 0.0):
            return

        Region := BuildLinearBoxRegion(
            Bounds,
            Configuration.EdgePadding
        )

        if(not IsValidLinearBoxRegion(Region)?):
            return

        # Por ahora solamente probaremos movimiento 1D.
        if(Configuration.MovementConstraint = movement_constraint.Plane2D):
            return

        var CurrentPosition : vector3 = InitialPosition

        var CurrentDirection : vector3 =
            GenerateInitialDirection(
                CurrentPosition,
                Region,
                Configuration.MovementConstraint
            )

        loop:

            DistanceToBoundary := GetDistanceToNextBoundary(
                CurrentPosition,
                CurrentDirection,
                Region,
                Configuration.MovementConstraint
            )

            TravelDistance := GenerateTravelDistance(DistanceToBoundary)

            NextPosition :=CurrentPosition + CurrentDirection * TravelDistance

            MoveTime := CalculateMoveTime(TravelDistance, Configuration.Speed)

            TargetObject.MoveTo(
                TargetIndex,
                NextPosition,
                MoveTime
            )

            set CurrentPosition = NextPosition

            set CurrentDirection = CurrentDirection * -1.0

             
    GenerateTravelDistance(DistanceToBoundary : float) : float =

        case(Configuration.DirectionChangeMode):

            linear_direction_change_mode.BoundsOnly =>
                DistanceToBoundary

            linear_direction_change_mode.DistanceBased =>
                DirectionChangeDistance :=
                    GetRandomFloat(
                        Configuration.MinDirectionChangeDistance,
                        Configuration.MaxDirectionChangeDistance
                    )

                if(DirectionChangeDistance < DistanceToBoundary):
                    DirectionChangeDistance
                else:
                    DistanceToBoundary