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
    dwarfVoice = {
        localizedFiles = {
            en = {
                "assets/sounds/classes/en/dwarf/01-raw-strength.mp3",
                "assets/sounds/classes/en/dwarf/02-make-way.mp3",
                "assets/sounds/classes/en/dwarf/03-easy-work.mp3",
                "assets/sounds/classes/en/dwarf/04-one-box.mp3",
            },
        },
        volume = 0.8,
    },
    wizardVoice = {
        localizedFiles = {
            en = {
                "assets/sounds/classes/en/wizard/01-by-the-stars.mp3",
                "assets/sounds/classes/en/wizard/02-no-barriers.mp3",
                "assets/sounds/classes/en/wizard/03-watch-this.mp3",
                "assets/sounds/classes/en/wizard/04-ancient-magic.mp3",
            },
        },
        volume = 1.0,
    },
    warriorVoice = {
        localizedFiles = {
            en = {
                "assets/sounds/classes/en/warrior/01-make-way.mp3",
                "assets/sounds/classes/en/warrior/02-clear-path.mp3",
                "assets/sounds/classes/en/warrior/03-stand-firm.mp3",
                "assets/sounds/classes/en/warrior/04-stone-yields.mp3",
            },
        },
        volume = 0.8,
    },
    farmerVoice = {
        localizedFiles = {
            en = {
                "assets/sounds/classes/en/farmer/01-new-growth.mp3",
                "assets/sounds/classes/en/farmer/02-time-for-trim.mp3",
                "assets/sounds/classes/en/farmer/03-grow-back-strong.mp3",
                "assets/sounds/classes/en/farmer/04-clear-path.mp3",
            },
        },
        volume = 0.8,
    },
    mysteriousPriestVoice = {
        localizedFiles = {
            en = {
                "assets/sounds/classes/en/mysterious_priest/01-within-my-aura.mp3",
                "assets/sounds/classes/en/mysterious_priest/02-one-step-for-all.mp3",
                "assets/sounds/classes/en/mysterious_priest/03-stay-in-circle.mp3",
                "assets/sounds/classes/en/mysterious_priest/04-stones-follow.mp3",
            },
        },
        volume = 0.8,
    },
    puppeteerVoice = {
        localizedFiles = {
            en = {
                "assets/sounds/classes/en/puppeteer/01-thread-and-stone.mp3",
                "assets/sounds/classes/en/puppeteer/02-strings-find-you.mp3",
                "assets/sounds/classes/en/puppeteer/03-whole-line-moves.mp3",
                "assets/sounds/classes/en/puppeteer/04-hold-the-thread.mp3",
            },
        },
        volume = 0.8,
    },
}
