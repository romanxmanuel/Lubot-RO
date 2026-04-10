-- BuffTimerUtil.lua
local RunService = game:GetService("RunService")

local BuffTimerUtil = {}
BuffTimerUtil.__index = BuffTimerUtil

--[[
    Buff structure:
    {
        name = string,
        duration = number,
        timeLeft = number,
        stacks = number,
        meta = any,
        onExpire = fn?,
        onTick = fn?,
        onApply = fn?
    }
]]

function BuffTimerUtil.new(updateStep: number?)
    local self = setmetatable({}, BuffTimerUtil)

    self._tracked = {} -- entity -> { buffName -> buffState }
    self._accum = 0
    self._updateStep = updateStep or 0.1 -- tick granularity

    self._conn = RunService.Heartbeat:Connect(function(dt)
        self:_update(dt)
    end)

    return self
end

function BuffTimerUtil:_update(dt)
    self._accum += dt
    if self._accum < self._updateStep then
        return
    end

    local step = self._accum
    self._accum = 0

    for entity, buffs in pairs(self._tracked) do
        for name, buff in pairs(buffs) do
            buff.timeLeft -= step

            if buff.onTick then
                buff.onTick(entity, buff)
            end

            if buff.timeLeft <= 0 then
                if buff.onExpire then
                    buff.onExpire(entity, buff)
                end
                buffs[name] = nil
            end
        end
    end
end

-- Create or refresh a buff
function BuffTimerUtil:apply(entity, name: string, duration: number, opts)
    opts = opts or {}

    local buffs = self._tracked[entity]
    if not buffs then
        buffs = {}
        self._tracked[entity] = buffs
    end

    local existing = buffs[name]

    if existing then
        if opts.mode == "extend" then
            existing.timeLeft += duration
        elseif opts.mode == "stack" then
            existing.stacks += 1
            existing.timeLeft = duration
        else -- default = refresh
            existing.timeLeft = duration
        end
        return existing
    end

    local buff = {
        name = name,
        duration = duration,
        timeLeft = duration,
        stacks = opts.stacks or 1,
        meta = opts.meta,
        onExpire = opts.onExpire,
        onTick = opts.onTick,
        onApply = opts.onApply,
    }

    buffs[name] = buff

    if buff.onApply then
        buff.onApply(entity, buff)
    end

    return buff
end

function BuffTimerUtil:remove(entity, name)
    local buffs = self._tracked[entity]
    if buffs and buffs[name] then
        buffs[name] = nil
    end
end

function BuffTimerUtil:has(entity, name)
    local buffs = self._tracked[entity]
    return buffs and buffs[name] ~= nil
end

function BuffTimerUtil:get(entity, name)
    local buffs = self._tracked[entity]
    return buffs and buffs[name] or nil
end

function BuffTimerUtil:getAll(entity)
    return self._tracked[entity]
end

function BuffTimerUtil:destroy()
    if self._conn then
        self._conn:Disconnect()
    end
    self._tracked = {}
end

return BuffTimerUtil
