local ParkourConfig = {
    Vault = {
        MAX_VAULT_HEIGHT = 4,
        BUFFER_CHECK = 3,
        MIN_VAULT_DISTANCE = 4,
        MAX_VAULT_DISTANCE = 15,
        MIN_VAULT_SPEED = 25,
        VAULT_DURATION = 0.3,
        TALL_VAULT_CONSUMPTION = 7.5,
        VAULT_CD = 0.75
    },

    Momentum = {
        MIN_MOVE_SPEED = 12,
        MAX_MOMENTUM = 100,
        MIN_MOMENTUM = 0,
        MAX_RISING_MOMENTUM = 25,
        MIN_RISING_MOMENTUM = 5,
        STARTUP_MOMENTUM = 15,
        SLIDING_CONSUMPTION_DECAY = 50,
        MIN_SLIDING_MOMENTUM = 65
    },

    Boost = {
        LUNGE_WINDOW = 0.2,
        LUNGE_HEIGHT = 15,
        LUNGE_POWER = 30,
        LUNGE_CD = 0.75,
        LUNGE_CONSUMPTION = 35
    },

    WallRun = {
        MIN_WALLRUN_MOMENTUM = 50,
        MAX_WALL_ATTACH_DISTANCE = 4,
        WALL_RUN_WINDOW = 2,
        WALL_RUN_DECAY = 33,
        INIT_WALLRUN_HEIGHT_BOOST = 20,
        WALL_ATTACH_PRESSURE = 5,
        WALL_RUN_CD = 0.5,
        WALL_REDIRECT_HORIZONTAL_POWER = 30,
        WALL_REDIRECT_UPWARD_POWER = 25
    },

    Recovery = {
        MIN_FALL_SPEED = -65,
        MAX_FALL_SPEED = -190,
        PERFECT_ROLL_WINDOW = 0.15,
        ROLL_WINDOW = 0.4,
        PERFECT_ROLL_CONSUMPTION = 25,
        ROLL_CONSUMPTION = 40,
        MIN_ROLL_SPEED = 20,
    }


}

return ParkourConfig