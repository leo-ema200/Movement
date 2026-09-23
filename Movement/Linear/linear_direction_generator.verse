using { /Verse.org/Random }
using { /Verse.org/SpatialMath }

GenerateInitialDirection(Position : vector3, Region : linear_box_region, Constraint : movement_constraint) : vector3 =

    case(Constraint):

        movement_constraint.Horizontal =>
            GenerateHorizontalInitialDirection(
                Position,
                Region
            )

        movement_constraint.Vertical =>
            GenerateVerticalInitialDirection(
                Position,
                Region
            )

        movement_constraint.Plane2D =>
            GeneratePlane2DInitialDirection(
                Position,
                Region
            )

GenerateHorizontalInitialDirection(Position : vector3, Region : linear_box_region) : vector3 =

    PositiveDistance := Region.LeftMax - Position.Left
    NegativeDistance := Position.Left - Region.LeftMin

    if(PositiveDistance <= DirectionEpsilon):

        return vector3{
            Left := -1.0
            Up := 0.0
            Forward := 0.0
        }

    if(NegativeDistance <= DirectionEpsilon):

        return vector3{
            Left := 1.0
            Up := 0.0
            Forward := 0.0
        }

    if(GetRandomFloat(0.0, 1.0) < 0.5):

        vector3{
            Left := 1.0
            Up := 0.0
            Forward := 0.0
        }

    else:

        vector3{
            Left := -1.0
            Up := 0.0
            Forward := 0.0
        }

GenerateVerticalInitialDirection(Position : vector3, Region : linear_box_region) : vector3 =

    PositiveDistance := Region.UpMax - Position.Up
    NegativeDistance := Position.Up - Region.UpMin

    if(PositiveDistance <= DirectionEpsilon):

        return vector3{
            Left := 0.0
            Up := -1.0
            Forward := 0.0
        }

    if(NegativeDistance <= DirectionEpsilon):

        return vector3{
            Left := 0.0
            Up := 1.0
            Forward := 0.0
        }

    if(GetRandomFloat(0.0, 1.0) < 0.5):

        vector3{
            Left := 0.0
            Up := 1.0
            Forward := 0.0
        }

    else:

        vector3{
            Left := 0.0
            Up := -1.0
            Forward := 0.0
        }

GeneratePlane2DInitialDirection(Position : vector3, Region : linear_box_region) : vector3 =

    for(Attempt := 0..15):

        Candidate := vector3{
            Left := GetRandomFloat(-1.0, 1.0)
            Up := GetRandomFloat(-1.0, 1.0)
            Forward := 0.0
        }

        if(Candidate.LengthSquared() > 0.0001):

            Direction := Candidate.MakeUnitVector()

            DistanceToBoundary := GetDistanceToNextBoundary(
                Position,
                Direction,
                Region,
                movement_constraint.Plane2D
            )

            if(DistanceToBoundary > DirectionEpsilon):

                return Direction

    # Fallback determinista:
    # apuntar hacia el centro del área.

    Center := vector3{
        Left := (Region.LeftMin + Region.LeftMax) * 0.5
        Up := (Region.UpMin + Region.UpMax) * 0.5
        Forward := Position.Forward
    }

    ToCenter := vector3{
        Left := Center.Left - Position.Left
        Up := Center.Up - Position.Up
        Forward := 0.0
    }

    if(ToCenter.LengthSquared() > 0.0001):

        ToCenter.MakeUnitVector()

    else:

        vector3{
            Left := 1.0
            Up := 0.0
            Forward := 0.0
        }