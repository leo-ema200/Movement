
linear_movement_configuration<public> :=class<concrete>(movement_configuration):

        DirectionChangeMode<public> : linear_direction_change_mode =
            linear_direction_change_mode.BoundsOnly

        MinDirectionChangeDistance<public> : float = 500.0
        MaxDirectionChangeDistance<public> : float = 900.0

        MinTurnAngleDegrees<public> : float = 5.0
        MaxTurnAngleDegrees<public> : float = 20.0

        TurnDistance<public> : float = 200.0

        ReverseMode<public> : linear_reverse_mode = linear_reverse_mode.Instant

        ReverseDistance<public> : float = 150.0