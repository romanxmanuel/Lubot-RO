--[[
	Camera Focus Helper Module
	
	A utility module for smoothly focusing the camera on targets in the workspace.
	
	Usage Examples:
		local focusOnTarget = require(ReplicatedStorage.SharedSource.Utilities.CameraFocusHelper)
		
		-- Focus with custom magnitudes
		focusOnTarget("TreeFoliagePack_593B82D4", "right", "down", "front", 12, 6, 24)
		
		-- Focus with smart defaults
		focusOnTarget(workspace.Effects_Unscripted.Celestial_Slash, "left", nil, "front")
		
		-- Focus using path string
		focusOnTarget("Workspace/Effects_Unscripted/Celestial_Slash", "left", "up", "front")
		
		-- Focus with custom tween options
		focusOnTarget("MyModel", "right", "up", "front", nil, nil, nil, {
			tweenTime = 1.0,
			hold = 2.0
		})
	
	Parameters:
		target: Instance | string - The target object, name, or path to focus on
		dirX: "left" | "right" | nil - Horizontal direction
		dirY: "up" | "down" | nil - Vertical direction
		dirZ: "front" | "back" | nil - Depth direction
		magX: number | nil - Horizontal magnitude (studs), nil for smart default
		magY: number | nil - Vertical magnitude (studs), nil for smart default
		magZ: number | nil - Depth magnitude (studs), nil for smart default
		opts: table | nil - Optional settings:
			- tweenTime: number - Duration of camera tween (default: 0.4)
			- hold: number - How long to hold before setting to Fixed (default: 0.5)
--]]

local TweenService = game:GetService("TweenService")
local cam = workspace.CurrentCamera

-- dirX: "left" | "right" | nil
-- dirY: "up"   | "down"  | nil
-- dirZ: "front"| "back"  | nil
-- magX, magY, magZ: numbers (studs) or nil for smart defaults
-- opts: {tweenTime:number, hold:number}
local function focusOnTarget(target, dirX, dirY, dirZ, magX, magY, magZ, opts)
	opts = opts or {}
	local tweenTime = opts.tweenTime or 0.4
	local holdTime = opts.hold or 0.5

	-- Resolve target:
	-- - Instance (Model/BasePart)      -> use directly
	-- - "Name"                         -> workspace:FindFirstChild("Name", true)
	-- - "A/B/C" path (slash-separated) -> descend from workspace
	local function resolveTarget(t)
		if typeof(t) == "Instance" then
			return t
		elseif typeof(t) == "string" then
			-- Path "A/B/C"?
			if t:find("/") then
				local node = workspace
				for seg in t:gmatch("[^/]+") do
					node = node:FindFirstChild(seg)
					if not node then
						return nil
					end
				end
				return node
			else
				-- Deep search by name from workspace
				return workspace:FindFirstChild(t, true)
			end
		end
		return nil
	end

	local obj = resolveTarget(target)
	if not obj then
		warn(("focusOnTarget: couldn't find target %s"):format(tostring(target)))
		return
	end

	-- Compute frame & size for Model or BasePart
	local cf, size
	if obj:IsA("Model") then
		cf, size = obj:GetBoundingBox()
	elseif obj:IsA("BasePart") then
		cf = obj.CFrame
		size = obj.Size
	else
		-- Try: if it has descendant parts, bound them as a pseudo-model
		local parts = {}
		for _, d in ipairs(obj:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		if #parts == 0 then
			warn(("focusOnTarget: target %s has no parts to frame"):format(obj:GetFullName()))
			return
		end
		local tmpModel = Instance.new("Model")
		for _, p in ipairs(parts) do
			p:Clone().Parent = tmpModel
		end
		cf, size = tmpModel:GetBoundingBox()
		tmpModel:Destroy()
	end

	local center = cf.Position

	-- sensible size-based defaults
	local radius = math.max(size.Magnitude * 0.35, 8)
	local defMagX = radius * 0.9 -- side offset
	local defMagZ = radius * 0.35 -- forward/back offset
	local defMagY = math.max(size.Y * 0.25, 4)

	-- normalize dir keywords -> (basis vector)
	local function axis(dir, posVec, negVec)
		if dir == nil then
			return Vector3.zero
		elseif dir == "right" or dir == "up" or dir == "front" then
			return posVec
		elseif dir == "left" or dir == "down" or dir == "back" then
			return negVec
		else
			warn(("Unknown direction '%s' (use left/right, up/down, front/back)"):format(tostring(dir)))
			return Vector3.zero
		end
	end

	-- choose magnitudes (nil -> default; 0 -> no movement)
	local mX = (magX ~= nil) and magX or defMagX
	local mY = (magY ~= nil) and magY or defMagY
	local mZ = (magZ ~= nil) and magZ or defMagZ

	-- basis vectors from object orientation
	local right = cf.RightVector
	local up = cf.UpVector
	local look = cf.LookVector

	-- apply directions per axis
	local xVec = axis(dirX, right, -right) * (mX or 0)
	local yVec = axis(dirY, up, -up) * (mY or 0)
	local zVec = axis(dirZ, look, -look) * (mZ or 0)

	-- final eye position
	local eye = center + xVec + yVec + zVec

	-- tween camera in, hold, then set Fixed
	cam.CameraType = Enum.CameraType.Scriptable
	local tween = TweenService:Create(cam, TweenInfo.new(tweenTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(eye, center),
	})
	tween:Play()
	tween.Completed:Wait()

	task.wait(holdTime)
	cam.CameraType = Enum.CameraType.Fixed
end

return focusOnTarget
