movement_configuration<public> := class<concrete>:

    Speed<public> : float = 600.0

    MovementConstraint<public> : movement_constraint =
        movement_constraint.Plane2D

    EdgePadding<public> : float = 50.0