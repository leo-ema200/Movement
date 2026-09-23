using { /Verse.org/SpatialMath }


linear_movement_state := class<concrete>:

    var CurrentDirection : vector3 = vector3{}

    var Phase : linear_movement_phase =
        linear_movement_phase.Straight

    var DistanceUntilDirectionChange : float = 0.0

    var TurnStartDirection : vector3 = vector3{}
    var TurnTargetDirection : vector3 = vector3{}

    var TurnDistanceTraveled : float = 0.0

    var ReverseDistanceTraveled : float = 0.0

