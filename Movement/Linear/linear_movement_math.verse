using { /Verse.org/SpatialMath }
using {GameData.ScenarioData.Definitions}

linear_box_region := struct:

    LeftMin : float
    LeftMax : float

    UpMin : float
    UpMax : float

BuildLinearBoxRegion(Bounds : target_spawn_box_bounds, EdgePadding : float) : linear_box_region =

    HalfWidth := Bounds.Width * 0.5
    HalfHeight := Bounds.Height * 0.5

    linear_box_region{
        LeftMin := Bounds.Center.Left - HalfWidth + EdgePadding
        LeftMax := Bounds.Center.Left + HalfWidth - EdgePadding

        UpMin := Bounds.Center.Up - HalfHeight + EdgePadding
        UpMax := Bounds.Center.Up + HalfHeight - EdgePadding
    }

IsValidLinearBoxRegion(Region : linear_box_region)<transacts> : logic =
    if:
        Region.LeftMax > Region.LeftMin
        Region.UpMax > Region.UpMin
    then:
        true
    else:
        false


DirectionEpsilon : float = 0.0001


GetAxisBoundaryDistance(PositionValue : float, DirectionValue : float, MinValue : float, MaxValue : float, FallbackDistance : float) : float =

    if(DirectionValue > DirectionEpsilon):

        (MaxValue - PositionValue) / DirectionValue

    else if(DirectionValue < -DirectionEpsilon):

        (MinValue - PositionValue) / DirectionValue

    else:

        FallbackDistance


GetDistanceToNextBoundary(Position : vector3, Direction : vector3, Region : linear_box_region, Constraint : movement_constraint) : float =

    RegionWidth := Region.LeftMax - Region.LeftMin
    RegionHeight := Region.UpMax - Region.UpMin

    # Es mayor que cualquier recorrido posible dentro del rectángulo.
    FallbackDistance := RegionWidth + RegionHeight + 1.0

    LeftDistance := GetAxisBoundaryDistance(
        Position.Left,
        Direction.Left,
        Region.LeftMin,
        Region.LeftMax,
        FallbackDistance
    )

    UpDistance := GetAxisBoundaryDistance(
        Position.Up,
        Direction.Up,
        Region.UpMin,
        Region.UpMax,
        FallbackDistance
    )

    case(Constraint):

        movement_constraint.Horizontal =>
            LeftDistance

        movement_constraint.Vertical =>
            UpDistance

        movement_constraint.Plane2D =>
            if(LeftDistance < UpDistance):
                LeftDistance
            else:
                UpDistance


