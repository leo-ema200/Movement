

linear_movement_configuration<public> := class(movement_configuration):
        
        Speed<override> : float = 600.0
        EdgePadding<override> : float = 50.0

        MinSegmentDistance<public> : float = 500.0
        MaxSegmentDistance<public> : float = 900.0

        BoundaryResponse<public> : linear_boundary_response = linear_boundary_response.ReverseAndComplete

linear_automatic_configuration<public> :=class<concrete>(linear_movement_configuration):

        DirectionChangeMode<public> : linear_direction_change_mode = linear_direction_change_mode.BoundsOnly
        MovementConstraint<public> : movement_constraint = movement_constraint.Plane2D


linear_manual_configuration<public> := class<concrete>(linear_movement_configuration):

        # 0° = Horizontal
        # 90° = Vertical
        # Los ángulos intermedios representan la inclinación de la línea.
        InclinationsDegrees<public> : []float = array{
                0.0,
                45.0,
                90.0
        }

        SelectionMode<public> : linear_manual_selection_mode = linear_manual_selection_mode.Ordered


       