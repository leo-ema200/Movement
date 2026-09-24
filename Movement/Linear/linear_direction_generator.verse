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
            GeneratePlane2DDirection(
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

GeneratePlane2DDirection(Position : vector3, Region : linear_box_region) : vector3 =

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


GenerateNextDirection(Position : vector3, CurrentDirection : vector3, Region : linear_box_region, Constraint : movement_constraint) : vector3 =
    case(Constraint):

        movement_constraint.Horizontal =>
            CurrentDirection * -1.0

        movement_constraint.Vertical =>
            CurrentDirection * -1.0

        movement_constraint.Plane2D =>
            GeneratePlane2DDirection(
                Position,
                Region
            )

########### Manual
GenerateManualDirection(Position : vector3, Region : linear_box_region, InclinationDegrees : float) : vector3 =

    ClampedInclination := ClampManualInclinationDegrees(InclinationDegrees)

    # 0° = Horizontal.
    if(ClampedInclination <= DirectionEpsilon):
        return vector3{
            Left := GenerateManualLeftSign(Position, Region)
            Up := 0.0
            Forward := 0.0
        }

    # 90° = Vertical.
    if(ClampedInclination >= 90.0 - DirectionEpsilon):
        return vector3{
            Left := 0.0
            Up := GenerateManualUpSign(Position, Region)
            Forward := 0.0
        }

    AngleRadians := DegreesToRadians(ClampedInclination)

    LeftMagnitude := Cos(AngleRadians)
    UpMagnitude := Sin(AngleRadians)

    vector3{
        Left := LeftMagnitude * GenerateManualLeftSign(Position, Region)
        Up := UpMagnitude * GenerateManualUpSign(Position, Region)
        Forward := 0.0
    }

ClampManualInclinationDegrees(InclinationDegrees : float) : float =

    if(InclinationDegrees < 0.0):
        0.0

    else if(InclinationDegrees > 90.0):
        90.0

    else:
        InclinationDegrees

GenerateManualLeftSign(Position : vector3, Region : linear_box_region) : float =

    # Estamos en el limite positivo de Left.
    # Solo podemos movernos hacia dentro.
    if(Position.Left >= Region.LeftMax - DirectionEpsilon):
        return -1.0

    # Estamos en el limite negativo de Left.
    # Solo podemos movernos hacia dentro.
    if(Position.Left <= Region.LeftMin + DirectionEpsilon):
        return 1.0

    # Si estamos dentro del bounds,
    # cualquier sentido horizontal es valido.
    if(GetRandomFloat(0.0, 1.0) < 0.5):
        1.0
    else:
        -1.0

GenerateManualUpSign(Position : vector3, Region : linear_box_region) : float =

    # Estamos en el limite superior.
    # Solo podemos movernos hacia dentro.
    if(Position.Up >= Region.UpMax - DirectionEpsilon):
        return -1.0

    # Estamos en el limite inferior.
    # Solo podemos movernos hacia dentro.
    if(Position.Up <= Region.UpMin + DirectionEpsilon):
        return 1.0

    # Si estamos dentro del bounds,
    # cualquier sentido vertical es valido.
    if(GetRandomFloat(0.0, 1.0) < 0.5):
        1.0
    else:
        -1.0