--!strict

local ReplicatedStorage = game:GetService('ReplicatedStorage')

local BlacksmithUIStateMachine = require(ReplicatedStorage.Shared.Progression.BlacksmithUIStateMachine)

local BlacksmithController = {
    currentState = BlacksmithUIStateMachine.States.Idle,
}

function BlacksmithController.transition(eventName: string)
    local transitions = BlacksmithUIStateMachine.Transitions[BlacksmithController.currentState]
    if not transitions then
        return BlacksmithController.currentState
    end

    local nextState = transitions[eventName]
    if nextState then
        BlacksmithController.currentState = nextState
    end

    return BlacksmithController.currentState
end

function BlacksmithController.start()
    -- TODO: bind preview, enhancement confirm, anticipation timeline, and result celebration UI.
    BlacksmithController.currentState = BlacksmithUIStateMachine.States.Idle
end

return BlacksmithController
