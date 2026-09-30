local ParkourConfig = {
    Vault = {
        MAX_VAULT_HEIGHT = 4,
        BUFFER_CHECK = 3,
        MIN_VAULT_DISTANCE = 4,
        MAX_VAULT_DISTANCE = 15,
        MIN_VAULT_SPEED = 25,
        VAULT_DURATION = 0.3,
        TALL_VAULT_CONSUMPTION = 7.5,
    },

    Momentum = {
        MIN_MOVE_SPEED = 12,
        MAX_MOMENTUM = 100,
        MIN_MOMENTUM = 0,
        MAX_RISING_MOMENTUM = 25,
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

    }


}

return ParkourConfig