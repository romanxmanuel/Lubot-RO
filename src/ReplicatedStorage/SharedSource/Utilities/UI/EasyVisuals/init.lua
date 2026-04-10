--[[

	EasyVisuals.lua
	Applies dynamic visual effects to UI elements using modular gradient, stroke,
	and dropshadow systems. Supports preset-based animations for text, frames,
	and billboard UIs with customizable speed, color, and behavior.

	Example Usage:
		-- Apply a rainbow gradient effect
		local effect = EasyVisuals.new(
			myFrame,        -- UIInstance (Frame/TextLabel/ImageLabel)
			"Rainbow",      -- preset name
			0.35            -- optional speed
		)

		-- Apply an animated shiny outline with custom color
		local outline = EasyVisuals.new(
			myTextLabel,    -- UIInstance
			"ShineOutline", -- preset name
			75,             -- speed
			5,              -- size
			false,          -- saveInstanceObjects
			Color3.fromRGB(187, 0, 255) -- optional custom color override
		)

	Parameter Breakdown:
		uiInstance (GuiObject)                    → The UI element to apply effects to.
		effectType (string)                       → Preset name located under `EasyVisuals.Presets`.
		speed (number?)                           → Optional. Animation speed (default: 0.007).
		size (number?)                            → Optional. Size/intensity multiplier.
		saveInstanceObjects (boolean?)            → Optional. Saves and restores existing effects.
		customColor (ColorSequence | Color3?)     → Optional. Override preset color(s).
		customTransparency (NumberSequence | number?) → Optional. Override transparency values.
		resumesOnVisible (boolean?)               → Optional. Automatically resumes on re-visibility.

	Supported Presets:
		"Rainbow", "Lava", "Gold", "ChromeStroke", "FireStroke", "ShineOutline", etc.
		Custom presets can be added to `EasyVisuals.Presets`.

	Features:
		- Gradient, Stroke, and Dropshadow animation engines
		- Automatic visibility-based pausing/resuming
		- Safe cleanup and restoration of original UI properties
		- Supports TextLabels, Frames, and BillboardGuis
		- Easily extendable through presets and gradient templates

	@author Arxk
	@maintained by Mys7o

]]

local Presets = script.Presets;

export type Effect<T...> = {
	UIInstance: GuiObject,
	EffectObjects: { Instance },
	SavedObjects: { Instance },
	Speed: number,
	Size: number,
	IsPaused: boolean,

	Pause: (self: Effect<T...>) -> nil,
	Resume: (self: Effect<T...>) -> nil,
	Destroy: (self: Effect<T...>) -> nil,
};

local Effect = {};
Effect.Gradient = require(script.Gradient);
Effect.Stroke = require(script.Stroke);
Effect.Dropshadow = require(script.Dropshadow);
Effect.Templates = require(script.GradientTemplates);

Effect.__index = Effect;
Effect.CurrentEffects = {};

local VisibleOrEnabledChart = {
	["GuiObject"] = "Visible",
	["ScreenGui"] = "Enabled",
	["BillboardGui"] = "Enabled",
	["SurfaceGui"] = "Enabled",
};

local function ValidateIsPreset(presetName: string): boolean
	return Presets:FindFirstChild(presetName) ~= nil;
end

-- Creates a new visual effect instance with customizable parameters
function Effect.new<T...>(
	uiInstance: GuiObject,                              -- GuiObject | The UI element to apply effects to (Frame, TextLabel, ImageLabel, etc.)
	effectType: string,                                 -- string | Preset name located under EasyVisuals.Presets
	speed: number?,                                     -- number? | Optional animation speed (default: 0.007)
	size: number?,                                      -- number? | Optional effect intensity or stroke size
	saveInstanceObjects: boolean?,                      -- boolean? | If true, saves and restores existing UIStroke/UIGradient
	customColor: ColorSequence | Color3?,               -- ColorSequence | Color3? | Optional override for preset colors
	customTransparency: NumberSequence | number?,       -- NumberSequence | number? | Optional override for transparency sequence
	resumesOnVisible: boolean?                          -- boolean? | Automatically resumes when UI becomes visible again
): Effect<T...>

	assert(uiInstance, "UIInstance not provided");
	assert(effectType, "EffectType not provided");
	assert(uiInstance:IsA("GuiObject"), "UIInstance is not a GuiObject");
	assert(typeof(effectType) == "string", "effectType is not a string");
	assert(ValidateIsPreset(effectType), "effectType is not a valid preset");

	if (speed) then
		assert(typeof(speed) == "number", "speed is not a number");
	end;

	if (size) then
		assert(typeof(size) == "number", "size is not a number");
	end;

	if (customColor) then
		assert(typeof(customColor) == "ColorSequence" or typeof(customColor) == "Color3", "customColor is not a ColorSequence or Color3");
	end;

	if (customTransparency) then
		assert(typeof(customTransparency) == "NumberSequence" or typeof(customTransparency) == "number", "customTransparency is not a NumberSequence or number");
	end;

	local self = {};
	self.IsPaused = false;
	self.Diagnostic = "DIAGNOSTIC VALUE";
	self.UIInstance = uiInstance;
	self.ResumesOnShown = resumesOnVisible == nil and true or resumesOnVisible;
	self.EffectObjects = {};
	self.SavedObjects = {};
	self.Connections = {};
	self.Speed = speed or 0.007;
	self.Size = size or 1;

	-- Climb up the parent tree of the UIInstance and attach GetPropertyChangedSignal to the Visible property of each object
	-- If the Visible property changes to false, destroy the effect
	local function RecursiveAncestryChanged(Object: Instance)
		if (not Object) then
			return;
		end;

		-- If the object is a PlayerGui or Workspace, stop climbing
		if (Object:IsA("PlayerGui") or Object:IsA("Workspace")) then
			return;
		end;

		-- If the object is a ScreenGui, BillboardGui, or SurfaceGui, check if it's enabled
		local IsVisibleOrEnabled = VisibleOrEnabledChart[Object.ClassName];
		if (not IsVisibleOrEnabled) then
			RecursiveAncestryChanged(Object.Parent);
			return;
		end;

		table.insert(self.Connections, Object:GetPropertyChangedSignal(IsVisibleOrEnabled):Connect(function()
			self.IsPaused = not Object[IsVisibleOrEnabled];

			if (self.IsPaused) then
				self:Pause();
			else
				if (self.ResumesOnShown) then
					self:Resume();
				end;
			end;
		end));

		RecursiveAncestryChanged(Object.Parent);
	end;
	RecursiveAncestryChanged(uiInstance);

	if (saveInstanceObjects) then
		for _, Object in uiInstance:GetChildren() do
			if (Object:IsA("UIStroke") or Object:IsA("UIGradient")) then
				table.insert(self.SavedObjects, Object);
				Object.Parent = nil;
			end;
		end;
	end;

	local Preset = require(Presets:FindFirstChild(effectType));
	local Objects = Preset(uiInstance, self.Speed, self.Size, customColor, customTransparency);

	if (Objects["Connections"]) then
		for _, Connection in Objects["Connections"] do
			table.insert(self.Connections, Connection);
		end;
	end;

	if (Objects["Effects"]) then
		for _, ObjectEffect in Objects["Effects"] do
			table.insert(self.EffectObjects, ObjectEffect);
		end;
	end;

	self.Connection = uiInstance.AncestryChanged:Connect(function()
		if (not uiInstance:IsDescendantOf(game)) then
			self:Destroy();
		end;
	end);

	return setmetatable(self, Effect);
end

function Effect:Pause()
	-- print("Effect paused");

	for _, Object in self.EffectObjects do
		if (Object.Pause) then
			Object:Pause();
		end;
	end;
end

function Effect:Resume()
	-- print("Effect resumed");

	for _, Object in self.EffectObjects do
		if (Object.Resume) then
			Object:Resume();
		end;
	end;
end

function Effect:Destroy()
	for _, Object in self.SavedObjects do
		Object.Parent = self.UIInstance;
	end;

	for _, Connection in self.Connections do
		Connection:Disconnect();
	end;

	table.clear(self.SavedObjects);
	table.clear(self.Connections);

	for _, Object in self.EffectObjects do
		if (not Object.Destroy) then
			continue;
		end;

		Object:Destroy();
	end;

	self.Connection:Disconnect();
end

return table.freeze(Effect);