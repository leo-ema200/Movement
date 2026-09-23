using {GameData.ScenarioData.Definitions}

movement_behavior<public> := interface:

    Run<public>(TargetObject : target, TargetIndex : int, Bounds : target_spawn_bounds)<suspends> : void = {}