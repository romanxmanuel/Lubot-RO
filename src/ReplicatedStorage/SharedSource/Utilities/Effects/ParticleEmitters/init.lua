--[[
	ParticleEmitter Utility Module
	Enhanced utility for managing ParticleEmitters with advanced features
	
	Features:
	- Enable/Disable emitters with lifetime management
	- Emit particles with quality scaling
	- Clone and customize effects
	- Batch operations on multiple effects
	- Automatic cleanup management
	- Support for PointLights alongside ParticleEmitters
	
	Architecture:
	This module delegates functionality to specialized sub-modules:
	- Core: Enable/Disable/Toggle operations
	- Emitter: Emit-based operations (PlayEmit, CloneEffect, PlaySequence)
	- RateManager: Emission rate management
	- Helpers: General helper functions and configuration
	- Scalers/: Folder containing all scaling operations
	  - SizeScaler: Size scaling with NumberSequence helpers
	  - SpeedScaler: Speed scaling with NumberRange helpers
	  - Scaler: Combined scaling operations
--]]

local ParticleEmitters = {}

-- Load sub-modules
local Core = require(script.Core)
local Emitter = require(script.Emitter)
local RateManager = require(script.RateManager)
local Helpers = require(script.Helpers)

-- Load scaling modules
local Scalers = require(script.Scalers)
local SizeScaler = Scalers.SizeScaler
local SpeedScaler = Scalers.SpeedScaler
local Scaler = Scalers.Scaler

-- Set up cross-module references
Emitter.Core = Core
Emitter.GetQualityLevel = Helpers.GetQualityLevel
Scaler.SizeScaler = SizeScaler
Scaler.SpeedScaler = SpeedScaler

-- Configuration (exposed from Helpers)
ParticleEmitters.QualityLevel = Helpers.QualityLevel
ParticleEmitters.EnableAutoCleanup = true -- Automatically cleanup disconnected threads

-- Core operations
ParticleEmitters.DisableDescendants = Core.DisableDescendants
ParticleEmitters.EnableDescendants = Core.EnableDescendants
ParticleEmitters.ToggleEmitters = Core.ToggleEmitters
ParticleEmitters.CleanupAllThreads = Core.CleanupAllThreads

-- Emitter operations
ParticleEmitters.PlayEmit = Emitter.PlayEmit
ParticleEmitters.CloneEffect = Emitter.CloneEffect
ParticleEmitters.PlaySequence = Emitter.PlaySequence

-- Rate management
ParticleEmitters.SetRateMultiplier = RateManager.SetRateMultiplier
ParticleEmitters.ResetRates = RateManager.ResetRates

-- Size scaling
ParticleEmitters.SaveOriginalSizes = SizeScaler.SaveOriginalSizes
ParticleEmitters.ScaleSizes = SizeScaler.ScaleSizes
ParticleEmitters.ResetSizes = SizeScaler.ResetSizes

-- Speed scaling
ParticleEmitters.SaveOriginalSpeeds = SpeedScaler.SaveOriginalSpeeds
ParticleEmitters.ScaleSpeeds = SpeedScaler.ScaleSpeeds
ParticleEmitters.ResetSpeeds = SpeedScaler.ResetSpeeds

-- Combined scaling
ParticleEmitters.ScaleParticles = Scaler.ScaleParticles
ParticleEmitters.ResetParticles = Scaler.ResetParticles

-- Helper functions
ParticleEmitters.GetEmitters = Helpers.GetEmitters
ParticleEmitters.SetQualityLevel = Helpers.SetQualityLevel

return ParticleEmitters
