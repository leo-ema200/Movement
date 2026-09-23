using { /Verse.org/SpatialMath }
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

            case(Configuration.ReverseMode):
                linear_reverse_mode.Instant =>
                    NextPosition :=CurrentPosition + CurrentDirection * DistanceToBoundary

                    MoveTime := CalculateMoveTime(DistanceToBoundary, Configuration.Speed)

                    TargetObject.MoveTo(
                        TargetIndex,
                        NextPosition,
                        MoveTime
                    )

                    set CurrentPosition = NextPosition

                    set CurrentDirection = CurrentDirection * -1.0

                linear_reverse_mode.Soft =>
                    EffectiveReverseDistance := if(Configuration.ReverseDistance < DistanceToBoundary) then Configuration.ReverseDistance else DistanceToBoundary

                    StraightDistance := DistanceToBoundary - EffectiveReverseDistance

                    # Primero viajamos normalmente hasta llegar
                    # al punto donde debe comenzar la desaceleración.

                    if(StraightDistance > DirectionEpsilon):
                        ReverseStartPosition := CurrentPosition + CurrentDirection * StraightDistance

                        MoveTime :=CalculateMoveTime(StraightDistance, Configuration.Speed)

                         TargetObject.MoveTo(
                            TargetIndex,
                            ReverseStartPosition,
                            MoveTime
                        )

                        set CurrentPosition = ReverseStartPosition

                        # Ahora ejecutamos la reversión suave.
                        if(EffectiveReverseDistance > DirectionEpsilon):

                            NewPosition :=
                                RunSoftReverse(
                                    TargetObject,
                                    TargetIndex,
                                    CurrentPosition,
                                    CurrentDirection,
                                    EffectiveReverseDistance
                                )

                            set CurrentPosition = NewPosition

                            set CurrentDirection = CurrentDirection * -1.0



    RunMovementSpeedProfile(TargetObject : target, TargetIndex : int, StartPosition : vector3, Direction : vector3, TravelDistance : float, Speed : float, SpeedProfile : []float)<suspends> : vector3 =

        SegmentDistance := TravelDistance / SoftReverseSegmentCount

        var CurrentPosition : vector3 = StartPosition

        for(SpeedRatio : SpeedProfile):

            SegmentSpeed := Speed * SpeedRatio

            NextPosition := CurrentPosition + Direction * SegmentDistance

            MoveTime :=CalculateMoveTime( SegmentDistance, SegmentSpeed)

            TargetObject.MoveTo(TargetIndex, NextPosition, MoveTime)

            set CurrentPosition = NextPosition

        CurrentPosition

    RunSoftReverse(TargetObject : target, TargetIndex : int, StartPosition : vector3, CurrentDirection : vector3, ReverseDistance : float)<suspends> : vector3 =
        # Primera mitad:
        # seguimos avanzando hacia el boundary,
        # pero desacelerando.

        BoundaryPosition :=
            RunMovementSpeedProfile(
                TargetObject,
                TargetIndex,
                StartPosition,
                CurrentDirection,
                ReverseDistance,
                Configuration.Speed,
                SoftReverseDecelerationProfile
            )

        ReversedDirection := CurrentDirection * -1.0

        # Segunda mitad:
        # nos alejamos del boundary mientras
        # recuperamos nuestra velocidad normal.

        FinalPosition :=
            RunMovementSpeedProfile(
                TargetObject,
                TargetIndex,
                BoundaryPosition,
                ReversedDirection,
                ReverseDistance,
                Configuration.Speed,
                SoftReverseAccelerationProfile
            )

        FinalPosition