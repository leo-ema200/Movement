using { /Verse.org/SpatialMath }
using { /Verse.org/Random }
using {GameData.ScenarioData.Definitions}

linear_movement<public> := class(movement_behavior):

    Configuration<public> : linear_movement_configuration = linear_automatic_configuration{}

    Run<override>(TargetObject : target, TargetIndex : int, Bounds : target_spawn_bounds)<suspends> : void =
        if(not ValidateMovementConfiguration[Configuration]):
            return
        # Linear V1 actualmente trabaja con Box Bounds.
        if:
            BoxBounds := target_spawn_box_bounds[Bounds]
            CurrentPosition := TargetObject.GetTargetPositions()[TargetIndex]
        then:
            if(AutomaticConfiguration := linear_automatic_configuration[Configuration]):
                RunAutomaticBoxMovement(
                    TargetObject,
                    TargetIndex,
                    BoxBounds,
                    CurrentPosition,
                    AutomaticConfiguration
                )
            else if(ManualConfiguration := linear_manual_configuration[Configuration]):
                RunManualBoxMovement(
                    TargetObject,
                    TargetIndex,
                    BoxBounds,
                    CurrentPosition,
                    ManualConfiguration
                )

    RunAutomaticBoxMovement(TargetObject : target, TargetIndex : int, Bounds : target_spawn_box_bounds, InitialPosition : vector3, AutomaticConfiguration : linear_automatic_configuration)<suspends> : void = 
        if(AutomaticConfiguration.Speed <= 0.0):
            return

        Region := BuildLinearBoxRegion(
            Bounds,
            AutomaticConfiguration.EdgePadding
        )

        if(not IsValidLinearBoxRegion(Region)?):
            return

        var CurrentPosition : vector3 = InitialPosition

        var CurrentDirection : vector3 =
            GenerateInitialDirection(
                CurrentPosition,
                Region,
                AutomaticConfiguration.MovementConstraint
            )

        loop:

            case(AutomaticConfiguration.DirectionChangeMode):

                linear_direction_change_mode.BoundsOnly =>
                    DistanceToBoundary := GetDistanceToNextBoundary(
                        CurrentPosition,
                        CurrentDirection,
                        Region,
                        AutomaticConfiguration.MovementConstraint
                    )

                    NextPosition := CurrentPosition + CurrentDirection * DistanceToBoundary

                    MoveTime := CalculateMoveTime(DistanceToBoundary, AutomaticConfiguration.Speed)

                    TargetObject.MoveTo(
                        TargetIndex,
                        NextPosition,
                        MoveTime
                    )

                    set CurrentPosition = NextPosition

                    set CurrentDirection = GenerateNextDirection(
                        CurrentPosition,
                        CurrentDirection,
                        Region,
                        AutomaticConfiguration.MovementConstraint
                    )

                linear_direction_change_mode.DistanceBased =>
                    var RemainingDistance : float =
                        GetRandomFloat(
                            AutomaticConfiguration.MinSegmentDistance,
                            AutomaticConfiguration.MaxSegmentDistance
                        )

                    loop:

                        DistanceToBoundary := GetDistanceToNextBoundary(
                            CurrentPosition,
                            CurrentDirection,
                            Region,
                            AutomaticConfiguration.MovementConstraint
                        )

                        TravelDistance :=
                            if(RemainingDistance < DistanceToBoundary):
                                RemainingDistance
                            else:
                                DistanceToBoundary

                        NextPosition := CurrentPosition + CurrentDirection * TravelDistance

                        MoveTime := CalculateMoveTime(TravelDistance, AutomaticConfiguration.Speed)

                        TargetObject.MoveTo(
                            TargetIndex,
                            NextPosition,
                            MoveTime
                        )

                        set CurrentPosition = NextPosition

                        set RemainingDistance -= TravelDistance

                        # Se completo toda la distancia del segmento.
                        if(RemainingDistance <= DirectionEpsilon):
                            break

                        # Si aun queda distancia significa que llegamos
                        # al boundary antes de completar el segmento.
                        #
                        # Horizontal y Vertical no utilizan BoundaryResponse.
                        # Al llegar al boundary el segmento termina.
                        if(AutomaticConfiguration.MovementConstraint = movement_constraint.Plane2D):
                            if(ShouldChangeDirectionAtBoundary(AutomaticConfiguration.BoundaryResponse)?):
                                break

                            # ReverseAndComplete.
                            set CurrentDirection = CurrentDirection * -1.0
                        else:
                            break

                    set CurrentDirection = GenerateNextDirection(
                        CurrentPosition,
                        CurrentDirection,
                        Region,
                        AutomaticConfiguration.MovementConstraint
                    )

    RunManualBoxMovement(TargetObject : target, TargetIndex : int, Bounds : target_spawn_box_bounds, InitialPosition : vector3, ManualConfiguration : linear_manual_configuration)<suspends> : void =
        if(ManualConfiguration.Speed <= 0.0):
            return

        if(ManualConfiguration.InclinationsDegrees.Length <= 0):
            return

        if(ManualConfiguration.MinSegmentDistance <= 0.0):
            return

        if(ManualConfiguration.MaxSegmentDistance <= 0.0):
            return

        Region := BuildLinearBoxRegion(
            Bounds,
            ManualConfiguration.EdgePadding
        )

        if(not IsValidLinearBoxRegion(Region)?):
            return

        var CurrentPosition : vector3 = InitialPosition

        var CurrentManualIndex : int =
            GenerateInitialManualIndex(
                ManualConfiguration
            )

        loop:

            if(InclinationDegrees := ManualConfiguration.InclinationsDegrees[CurrentManualIndex]):

                var CurrentDirection : vector3 =
                    GenerateManualDirection(
                        CurrentPosition,
                        Region,
                        InclinationDegrees
                    )

                var RemainingDistance : float =
                    GetRandomFloat(
                        ManualConfiguration.MinSegmentDistance,
                        ManualConfiguration.MaxSegmentDistance
                    )

                loop:

                    DistanceToBoundary := GetDistanceToNextBoundary(
                        CurrentPosition,
                        CurrentDirection,
                        Region,
                        movement_constraint.Plane2D
                    )

                    TravelDistance :=
                        if(RemainingDistance < DistanceToBoundary):
                            RemainingDistance
                        else:
                            DistanceToBoundary

                    NextPosition := CurrentPosition + CurrentDirection * TravelDistance

                    MoveTime := CalculateMoveTime(
                        TravelDistance,
                        ManualConfiguration.Speed
                    )

                    TargetObject.MoveTo(
                        TargetIndex,
                        NextPosition,
                        MoveTime
                    )

                    set CurrentPosition = NextPosition

                    set RemainingDistance -= TravelDistance

                    # El segmento manual completo toda su distancia.
                    if(RemainingDistance <= DirectionEpsilon):
                        break

                    # El boundary interrumpio el segmento.
                    #
                    # ChangeDirection:
                    # termina este segmento y pasa a la siguiente
                    # configuracion manual.
                    #
                    # ReverseAndComplete:
                    # mantiene esta configuracion manual y completa
                    # la distancia restante en direccion contraria.
                    if(ShouldChangeDirectionAtBoundary(ManualConfiguration.BoundaryResponse)?):
                        break

                    # ReverseAndComplete.
                    set CurrentDirection = CurrentDirection * -1.0

                set CurrentManualIndex =
                    GenerateNextManualIndex(
                        CurrentManualIndex,
                        ManualConfiguration
                    )

            else:
                return
 
    ShouldChangeDirectionAtBoundary(BoundaryResponse : linear_boundary_response)<transacts> : logic =

        case(BoundaryResponse):

            linear_boundary_response.ChangeDirection =>
                true

            linear_boundary_response.ReverseAndComplete =>
                false

            linear_boundary_response.Random =>
                if(GetRandomFloat(0.0, 1.0) < 0.5):
                    true
                else:
                    false


    GenerateInitialManualIndex(ManualConfiguration : linear_manual_configuration) : int =

        case(ManualConfiguration.SelectionMode):

            linear_manual_selection_mode.Ordered =>
                0

            linear_manual_selection_mode.Random =>
                GetRandomInt(
                    0,
                    ManualConfiguration.InclinationsDegrees.Length - 1
                )

    GenerateNextManualIndex(CurrentManualIndex : int, ManualConfiguration : linear_manual_configuration) : int =

        case(ManualConfiguration.SelectionMode):

            linear_manual_selection_mode.Ordered =>
                NextManualIndex := CurrentManualIndex + 1

                if(NextManualIndex >= ManualConfiguration.InclinationsDegrees.Length):
                    0
                else:
                    NextManualIndex

            linear_manual_selection_mode.Random =>
                GetRandomInt(
                    0,
                    ManualConfiguration.InclinationsDegrees.Length - 1
                )
