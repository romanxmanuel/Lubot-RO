--!strict

local BlacksmithUIStateMachine = {
    States = {
        Idle = 'Idle',
        Inspecting = 'Inspecting',
        Ready = 'Ready',
        Anticipating = 'Anticipating',
        Resolving = 'Resolving',
        Success = 'Success',
        Failure = 'Failure',
        Destroyed = 'Destroyed',
        Error = 'Error',
    },
    Events = {
        SelectItem = 'SelectItem',
        ToggleProtection = 'ToggleProtection',
        StartEnhancement = 'StartEnhancement',
        ResultResolved = 'ResultResolved',
        Reset = 'Reset',
    },
    Transitions = {
        Idle = {
            SelectItem = 'Inspecting',
        },
        Inspecting = {
            ToggleProtection = 'Ready',
            StartEnhancement = 'Anticipating',
            Reset = 'Idle',
        },
        Ready = {
            ToggleProtection = 'Ready',
            StartEnhancement = 'Anticipating',
            Reset = 'Idle',
        },
        Anticipating = {
            ResultResolved = 'Resolving',
        },
        Resolving = {
            ResultResolved = 'Success',
            Reset = 'Idle',
        },
        Success = {
            Reset = 'Idle',
        },
        Failure = {
            Reset = 'Idle',
        },
        Destroyed = {
            Reset = 'Idle',
        },
        Error = {
            Reset = 'Idle',
        },
    },
    PresentationHooks = {
        showHammerGlow = true,
        showTownBroadcastPulse = true,
        showCountdownBeats = true,
        playAnvilChargeSfx = true,
        playResultSting = true,
    },
}

return BlacksmithUIStateMachine
