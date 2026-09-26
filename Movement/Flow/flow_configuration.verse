using { /Verse.org/Simulation }

flow_space<public> := enum:
    ViewPlane
    GroundPlane

FlowSpeedTip<localizes> : message = "10..2000 cm/s during MoveTo. Experimental sleeps add wall-clock time."
FlowPaddingTip<localizes> : message = "0..1000000 cm. Automatically capped at 45% of each active box dimension."
FlowHeadingTip<localizes> : message = "0..360 degrees: 0 = +Left; 90 = +Up (ViewPlane) or +Forward (GroundPlane). Bounds reflect this trend."
FlowSpreadTip<localizes> : message = "0..180 degrees around the trend. 0 is straight between bounds; larger values widen the scribble."
FlowSpanTip<localizes> : message = "25..2000 cm between steering decisions, before random variation and automatic bounds fitting."
FlowPersistenceTip<localizes> : message = "0..0.95. Retained fraction of the previous angular deviation. Higher = slower changes."
FlowSwitchTip<localizes> : message = "0..1. Probability of switching the deviation side at a decision (1 = alternating S-like bends)."
FlowRandomTip<localizes> : message = "0..1. Variation of bend amplitude and decision distance. 0 makes side decisions deterministic."
FlowSeedTip<localizes> : message = "0 = fresh random stream each Run. Positive seed reproduces a stream per TargetIndex for A/B tests."
FlowClearanceTip<localizes> : message = "0..2000 cm protected radius around each player; include player + target size. 0 explicitly disables protection."
FlowSleepTip<localizes> : message = "EXPERIMENT: Sleep(0.1) before every curved MoveTo chord. Compare OFF/ON visually; remove if worse."

flow_configuration<public> := class<concrete>(movement_configuration):
    @editable_number(float):
        MinValue := option{10.0}
        MaxValue := option{2000.0}
        ToolTip := FlowSpeedTip
    Speed<override> : float = 350.0

    @editable_number(float):
        MinValue := option{0.0}
        MaxValue := option{1000000.0}
        ToolTip := FlowPaddingTip
    EdgePadding<override> : float = 50.0

    @editable
    Space<public> : flow_space = flow_space.ViewPlane

    @editable_number(float):
        MinValue := option{0.0}
        MaxValue := option{360.0}
        ToolTip := FlowHeadingTip
    HeadingDegrees<public> : float = 90.0

    @editable_number(float):
        MinValue := option{0.0}
        MaxValue := option{180.0}
        ToolTip := FlowSpreadTip
    SpreadDegrees<public> : float = 35.0

    @editable_number(float):
        MinValue := option{25.0}
        MaxValue := option{2000.0}
        ToolTip := FlowSpanTip
    TurnDistance<public> : float = 300.0

    @editable_number(float):
        MinValue := option{0.0}
        MaxValue := option{0.95}
        ToolTip := FlowPersistenceTip
    Persistence<public> : float = 0.25

    @editable_number(float):
        MinValue := option{0.0}
        MaxValue := option{1.0}
        ToolTip := FlowSwitchTip
    SideSwitchChance<public> : float = 0.65

    @editable_number(float):
        MinValue := option{0.0}
        MaxValue := option{1.0}
        ToolTip := FlowRandomTip
    Randomness<public> : float = 0.8

    @editable_number(int):
        MinValue := option{0}
        MaxValue := option{2147483646}
        ToolTip := FlowSeedTip
    Seed<public> : int = 0

    @editable_number(float):
        MinValue := option{0.0}
        MaxValue := option{2000.0}
        ToolTip := FlowClearanceTip
    PlayerClearance<public> : float = 150.0

    @editable:
        ToolTip := FlowSleepTip
    ExperimentalSleep<public> : logic = true
