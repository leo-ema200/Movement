using { /Verse.org/Simulation }

movement_configuration<public> := class<concrete>:
    # Positive speed (cm/s); editor lower bound, runtime checks remain in behaviors.
    @editable_number(float):
        MinValue := option{0.01}
    Speed<public> : float = 600.0
    # Nonnegative inset (cm). Bounds-dependent upper limit belongs to each behavior.
    @editable_number(float):
        MinValue := option{0.0}
    EdgePadding<public> : float = 50.0

# Editor attributes do not validate values constructed in code or older serialized data.
ValidateMovementConfiguration<public>(Config : movement_configuration)<transacts><decides> : void =
    Config.Speed.IsFinite[]
    Config.Speed > 0.0
    Config.EdgePadding.IsFinite[]
    Config.EdgePadding >= 0.0
