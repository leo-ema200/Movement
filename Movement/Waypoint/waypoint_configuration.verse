using { /Verse.org/SpatialMath }
using { /Verse.org/Simulation }

waypoint_space<public> := enum:
    ViewPlane
    GroundPlane
    Volume

waypoint_traversal<public> := enum:
    Loop
    PingPong
    Random

waypoint_configuration<public> := class<concrete>(movement_configuration):
    # 0.01+ cm/s; runtime still rejects nonfinite/nonpositive values.
    @editable_number(float):
        MinValue := option{0.01}
    Speed<override> : float = 600.0

    # 0+ cm; must also fit the selected bounds at runtime.
    @editable_number(float):
        MinValue := option{0.0}
    EdgePadding<override> : float = 50.0

    # ViewPlane: Left/Up, preserve starting Forward.
    # GroundPlane: Left/Forward, preserve starting Up. Volume: all three axes.
    @editable
    Space<public> : waypoint_space = waypoint_space.ViewPlane

    # Coordinates in [-1, 1] relative to the padded box. Inactive axes are ignored.
    # UEFN has no per-element vector range attribute on []vector3; validated at runtime.
    @editable
    Points<public> : []vector3 = array{
        vector3{Left := -0.8, Up := -0.5, Forward := -0.6},
        vector3{Left := 0.6, Up := -0.7, Forward := -0.5},
        vector3{Left := 0.8, Up := 0.5, Forward := 0.7},
        vector3{Left := -0.4, Up := 0.8, Forward := 0.5}
    }

    @editable
    Traversal<public> : waypoint_traversal = waypoint_traversal.Random

    # Applies to Loop/PingPong. Random traversal always chooses independently.
    @editable
    RandomStart<public> : logic = true

    # Per-visit variation, as a fraction of each active axis's usable half-extent.
    @editable_number(float):
        MinValue := option{0.0}
        MaxValue := option{1.0}
    JitterFraction<public> : float = 0.08

    # Reject shorter route legs instead of sending tiny MoveTo calls. Units: cm.
    @editable_number(float):
        MinValue := option{1.0}
    MinLegDistance<public> : float = 50.0
