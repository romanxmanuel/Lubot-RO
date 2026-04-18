-- AssetRegistry.lua
-- Path: ReplicatedStorage/Combat/AssetRegistry
-- SOURCE: Copied from ChatGPT design session https://chatgpt.com/c/69e31ae1-fbc8-83ea-be7f-0989d3156054
-- Fill in rbxassetid values as you source them from Roblox Creator Store / Pixabay

local AssetRegistry = {
	Animations = {
		Hit1 = "rbxassetid://0",
		Hit2 = "rbxassetid://0",
		Hit3 = "rbxassetid://0",
		Hit4 = "rbxassetid://0",
		Hit5 = "rbxassetid://0",
	},
	VFX = {
		-- NOTE: These are sourced by cloning from workspace > VFX Drops, NOT by asset ID
		-- Hit1 & Hit4 -> workspace["VFX Drops"]["Hakari Aura"]
		-- Hit2 & Hit3 -> workspace["VFX Drops"]["Meteor"]
		-- Hit5        -> workspace["VFX Drops"]["Portal"]
		Blink                = "rbxassetid://0",
		GreenLightningBurst  = "rbxassetid://0",
		GreenLightningBurstHeavy = "rbxassetid://0",
		Meteor               = "rbxassetid://0",
		MeteorDrop           = "rbxassetid://0",
		ShockwaveRing        = "rbxassetid://0",
		Crater               = "rbxassetid://0",
		DustBurst            = "rbxassetid://0",
		FinalNuke            = "rbxassetid://0",
		CastFlash            = "rbxassetid://0",
	},
	SFX = {
		BlinkWhoosh          = "rbxassetid://0",
		HitCrack             = "rbxassetid://0",
		HitCrackHeavy        = "rbxassetid://0",
		ElectricBurst        = "rbxassetid://0",
		ElectricBurstHeavy   = "rbxassetid://0",
		MeteorFall           = "rbxassetid://0",
		MeteorImpact         = "rbxassetid://0",
		Shockwave            = "rbxassetid://0",
		NukeCharge           = "rbxassetid://0",
		NukeBlast            = "rbxassetid://0",
		RecoilWhoosh         = "rbxassetid://0",
	},
}

return AssetRegistry
