# using { /Fortnite.com/Devices }
# using { /Verse.org/Simulation }
# using { /Verse.org/SpatialMath }
# using { GameData.ScenarioData.Definitions }

# FlowExtentTip<localizes> : message = "2+ cm, full Box dimension. Targets must start inside the box."
# FlowDurationTip<localizes> : message = "1..600 seconds. Stops all preview Runs by structured cancellation."

# flow_preview_device2<public> := class(creative_device):
#     @editable
#     Targets : []creative_prop = array{}

#     @editable
#     Configuration : flow_configuration = flow_configuration{}

#     # World center: unrestricted finite coordinates (no mathematical min/max).
#     @editable
#     Center : vector3 = vector3{Up := 300.0}

#     @editable_number(float):
#         MinValue := option{2.0}
#         ToolTip := FlowExtentTip
#     Width : float = 1400.0

#     @editable_number(float):
#         MinValue := option{2.0}
#         ToolTip := FlowExtentTip
#     Height : float = 800.0

#     @editable_number(float):
#         MinValue := option{2.0}
#         ToolTip := FlowExtentTip
#     Depth : float = 1400.0

#     @editable_number(float):
#         MinValue := option{1.0}
#         MaxValue := option{600.0}
#         ToolTip := FlowDurationTip
#     PreviewSeconds : float = 60.0

#     @editable
#     RunChecks : logic = true

#     OnBegin<override>()<suspends> : void =
#         if(RunChecks?):
#             Passed := RunFlowChecks()
#             if(not Passed?):
#                 return
#         Items := for(Prop : Targets, Prop.IsValid[]):
#             target_item(creative_prop){Target := Prop}
#         TargetObject := target_props{Targets := Items}
#         Behavior := flow_movement{Configuration := Configuration, Playspace := option{GetPlayspace()}}
#         Bounds := target_spawn_box_bounds{Center := Center, Width := Width, Height := Height, Depth := Depth}
#         # Same behavior AND configuration instance for every index.
#         race:
#             RunTargets(Behavior, TargetObject, Bounds, 0, Items.Length)
#             Sleep(FlowFinite(PreviewSeconds, 1.0, 600.0, 60.0))

#     RunTargets(Behavior : flow_movement, TargetObject : target, Bounds : target_spawn_bounds, Index : int, Count : int)<suspends> : void =
#         if(Index < Count):
#             sync:
#                 Behavior.Run(TargetObject, Index, Bounds)
#                 RunTargets(Behavior, TargetObject, Bounds, Index + 1, Count)

