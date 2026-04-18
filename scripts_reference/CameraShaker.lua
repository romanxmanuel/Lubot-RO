-- CameraShaker.lua
-- Path: ReplicatedStorage/Combat/CameraShaker
-- SOURCE: Copied from ChatGPT design session https://chatgpt.com/c/69e31ae1-fbc8-83ea-be7f-0989d3156054

local RunService = game:GetService("RunService")

local CameraShaker = {}
CameraShaker.__index = CameraShaker

local function noiseShake(t, frequency)
	return math.noise(t * frequency, 0, 0)
end

function CameraShaker.new(camera)
	local self = setmetatable({}, CameraShaker)
	self.Camera = camera
	self.Active = {}
	self._bound = false
	return self
end

function CameraShaker:AddShake(data)
	table.insert(self.Active, {
		Start = os.clock(),
		Duration = data.Duration,
		Amplitude = data.Amplitude or 0.2,
		Rotation = math.rad(data.Rotation or 1),
		Frequency = data.Frequency or 20,
	})
	self:Bind()
end

function CameraShaker:Bind()
	if self._bound then
		return
	end
	self._bound = true
	RunService:BindToRenderStep("AAACombatCameraShake", Enum.RenderPriority.Camera.Value + 1, function()
		if #self.Active == 0 then
			return
		end
		local now = os.clock()
		local cam = self.Camera
		local base = cam.CFrame
		local offset = Vector3.zero
		local rotX, rotY = 0, 0
		for i = #self.Active, 1, -1 do
			local s = self.Active[i]
			local elapsed = now - s.Start
			if elapsed >= s.Duration then
				table.remove(self.Active, i)
			else
				local alpha = 1 - (elapsed / s.Duration)
				local n1 = noiseShake(elapsed + i * 0.1, s.Frequency)
				local n2 = noiseShake(elapsed + i * 0.2, s.Frequency)
				local n3 = noiseShake(elapsed + i * 0.3, s.Frequency)
				offset += Vector3.new(n1, n2, n3) * s.Amplitude * alpha
				rotX += n2 * s.Rotation * alpha
				rotY += n1 * s.Rotation * alpha
			end
		end
		cam.CFrame = base * CFrame.new(offset) * CFrame.Angles(rotX, rotY, 0)
		if #self.Active == 0 then
			RunService:UnbindFromRenderStep("AAACombatCameraShake")
			self._bound = false
		end
	end)
end

return CameraShaker
