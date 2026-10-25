-- Set `file` to an audio path to replace a generated sound with an asset.
return {
    move = {
        file = "assets/sounds/footstep.mp3",
        volume = 0.55,
    },
    invalidMovement = {
        file = nil,
        volume = 0.42,
        synthesis = {
            duration = 0.16,
            startFrequency = 112,
            endFrequency = 68,
            decay = 15,
            harmonic = 0.42,
            noise = 0.11,
        },
    },
    undo = {
        file = "assets/sounds/undo.mp3",
        volume = 0.65,
    },
    teleport = {
        file = "assets/sounds/teleport.mp3",
        volume = 0.65,
    },
    target = {
        file = "assets/sounds/target_click.mp3",
        volume = 0.65,
    },
    grassChange = {
        file = "assets/sounds/grass_cut_grow.mp3",
        volume = 0.65,
    },
    grassFire = {
        file = "assets/sounds/grass_fire.mp3",
        volume = 0.65,
    },
    bodyFall = {
        file = "assets/sounds/body_fall.mp3",
        volume = 0.65,
    },
    menuSelect = {
        file = "assets/sounds/menu_select.mp3",
        volume = 0.55,
    },
    menuClick = {
        file = "assets/sounds/menu_click.mp3",
        volume = 0.65,
    },
}
