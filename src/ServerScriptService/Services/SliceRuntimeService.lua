--!strict

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

local GameplayNetDefs = require(ReplicatedStorage.Shared.Net.GameplayNetDefs)
local ArchetypeDefs = require(ReplicatedStorage.Shared.DataDefs.Progression.ArchetypeDefs)
local CardDefs = require(ReplicatedStorage.Shared.DataDefs.Cards.CardDefs)
local ClassStageDefs = require(ReplicatedStorage.Shared.DataDefs.Progression.ClassStageDefs)
local Dungeons = require(ReplicatedStorage.Shared.DataDefs.Dungeons.DungeonDefs)
local ItemDefs = require(ReplicatedStorage.Shared.DataDefs.Items.ItemDefs)
local ShopDefs = require(ReplicatedStorage.Shared.DataDefs.Items.ShopDefs)
local SkillDefs = require(ReplicatedStorage.Shared.DataDefs.Skills.SkillDefs)
local SkillLoadout = require(ReplicatedStorage.Shared.Skills.SkillLoadout)
local AdminConfig = require(script.Parent.Parent.Config.AdminConfig)

local ChatService = require(script.Parent.ChatService)
local CombatService = require(script.Parent.CombatService)
local DungeonService = require(script.Parent.DungeonService)
local EnemyService = require(script.Parent.EnemyService)
local InventoryService = require(script.Parent.InventoryService)
local PartyService = require(script.Parent.PartyService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StatService = require(script.Parent.StatService)
local WorldService = require(script.Parent.WorldService)
local EnhancementFormula = require(ReplicatedStorage.Shared.Progression.EnhancementFormula)
local EnhancementSystem = require(script.Parent.Parent.Systems.Enhancement.EnhancementSystem)

local SliceRuntimeService = {}

local remotesFolder = nil
local events = {}
local functionsMap = {}
local ARCHETYPE_VISUALS_FOLDER_NAME = 'ArchetypeVisuals'
local EQUIPMENT_VISUALS_FOLDER_NAME = 'EquipmentVisuals'
local CHAOS_EDGE_MESH_ID = 'rbxassetid://93180631'
local CHAOS_EDGE_TEXTURE_ID = 'rbxassetid://6991559849'
local SHADOW_CRESCENDO_TEXTURE_ID = 'rbxassetid://10089439752'

local function getSkillDisplayName(skillId: any): string
    if type(skillId) ~= 'string' then
        return tostring(skillId)
    end

    local definition = SkillDefs[skillId]
    local skillName = type(definition) == 'table' and (definition.displayName or definition.name) or nil
    if type(skillName) == 'string' and skillName ~= '' then
        return skillName
    end

    return skillId
end

local function ensureRemoteEvent(name: string)
    local found = nil
    for _, child in ipairs(remotesFolder:GetChildren()) do
        if child.Name == name then
            if child:IsA('RemoteEvent') then
                if not found then
                    found = child
                else
                    child:Destroy()
                end
            else
                child:Destroy()
            end
        end
    end

    if found then
        return found
    end

    local remote = Instance.new('RemoteEvent')
    remote.Name = name
    remote.Parent = remotesFolder
    return remote
end

local function ensureRemoteFunction(name: string)
    local found = nil
    for _, child in ipairs(remotesFolder:GetChildren()) do
        if child.Name == name then
            if child:IsA('RemoteFunction') then
                if not found then
                    found = child
                else
                    child:Destroy()
                end
            else
                child:Destroy()
            end
        end
    end

    if found then
        return found
    end

    local remote = Instance.new('RemoteFunction')
    remote.Name = name
    remote.Parent = remotesFolder
    return remote
end

local function getCharacterHumanoid(player)
    local character = player.Character
    return character and character:FindFirstChildOfClass('Humanoid')
end

local function getRigPart(character, partNames)
    for _, partName in ipairs(partNames) do
        local candidate = character:FindFirstChild(partName)
        if candidate and candidate:IsA('BasePart') then
            return candidate
        end
    end

    return nil
end

local function buildRigPartMap(character)
    return {
        head = getRigPart(character, { 'Head' }),
        torso = getRigPart(character, { 'UpperTorso', 'Torso' }),
        lowerTorso = getRigPart(character, { 'LowerTorso', 'Torso' }),
        rightUpperArm = getRigPart(character, { 'RightUpperArm', 'Right Arm' }),
        leftUpperArm = getRigPart(character, { 'LeftUpperArm', 'Left Arm' }),
        rightLowerArm = getRigPart(character, { 'RightLowerArm', 'Right Arm' }),
        leftLowerArm = getRigPart(character, { 'LeftLowerArm', 'Left Arm' }),
        rightHand = getRigPart(character, { 'RightHand', 'Right Arm' }),
        leftHand = getRigPart(character, { 'LeftHand', 'Left Arm' }),
    }
end

local function attachVisualPart(container, rigParts, spec)
    local anchorPart = rigParts[spec.anchor]
    if not anchorPart then
        return nil
    end

    local part = Instance.new('Part')
    part.Name = spec.name
    part.Size = spec.size
    part.Shape = spec.shape or Enum.PartType.Block
    part.Material = spec.material or Enum.Material.SmoothPlastic
    part.Color = spec.color
    part.Transparency = spec.transparency or 0
    part.Massless = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.CFrame = anchorPart.CFrame * spec.offset
    part.Parent = container

    local meshId = type(spec.meshId) == 'string' and spec.meshId or ''
    if meshId ~= '' then
        local mesh = Instance.new('SpecialMesh')
        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = meshId
        mesh.TextureId = type(spec.textureId) == 'string' and spec.textureId or ''
        if typeof(spec.meshScale) == 'Vector3' then
            mesh.Scale = spec.meshScale
        end
        if typeof(spec.meshOffset) == 'Vector3' then
            mesh.Offset = spec.meshOffset
        end
        mesh.Parent = part
    end

    local weld = Instance.new('WeldConstraint')
    weld.Part0 = anchorPart
    weld.Part1 = part
    weld.Parent = part

    return part
end

local function addChaosEdgeAura(part)
    local attachment = Instance.new('Attachment')
    attachment.Name = 'ChaosAura'
    attachment.Position = Vector3.new(0, 1.2, 0)
    attachment.Parent = part

    local flame = Instance.new('ParticleEmitter')
    flame.Name = 'ChaosFlame'
    flame.Texture = 'rbxasset://textures/particles/fire_main.dds'
    flame.Color = ColorSequence.new(
        Color3.fromRGB(255, 110, 84),
        Color3.fromRGB(255, 214, 168)
    )
    flame.LightEmission = 0.75
    flame.Brightness = 2.5
    flame.Lifetime = NumberRange.new(0.28, 0.46)
    flame.Rate = 16
    flame.Speed = NumberRange.new(0.1, 0.55)
    flame.Acceleration = Vector3.new(0, 0.9, 0)
    flame.SpreadAngle = Vector2.new(10, 10)
    flame.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.24),
        NumberSequenceKeypoint.new(1, 0.03),
    })
    flame.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.14),
        NumberSequenceKeypoint.new(1, 1),
    })
    flame.Parent = attachment

    local glow = Instance.new('PointLight')
    glow.Name = 'ChaosGlow'
    glow.Color = Color3.fromRGB(255, 112, 92)
    glow.Range = 8
    glow.Brightness = 1.15
    glow.Shadows = false
    glow.Parent = part
end

local function buildWeaponVisual(container, rigParts, weaponItemId: string?)
    if type(weaponItemId) ~= 'string' or weaponItemId == '' then
        return
    end

    if weaponItemId == 'sword' then
        local sword = attachVisualPart(container, rigParts, {
            name = 'KnightChaosEdge',
            anchor = 'rightLowerArm',
            size = Vector3.new(0.55, 5.24, 0.2),
            offset = CFrame.new(0.58, 1.12, 0.12),
            color = Color3.fromRGB(99, 95, 98),
            material = Enum.Material.SmoothPlastic,
            meshId = CHAOS_EDGE_MESH_ID,
            textureId = CHAOS_EDGE_TEXTURE_ID,
            meshScale = Vector3.new(0.65, 0.65, 0.5),
        })
        if sword then
            addChaosEdgeAura(sword)
        end
        return
    end
end

local function createParticleAura(container, rigParts, spec)
    local anchorPart = rigParts[spec.anchor]
    if not anchorPart then
        return nil
    end

    local anchor = Instance.new('Part')
    anchor.Name = spec.name
    anchor.Size = Vector3.new(0.2, 0.2, 0.2)
    anchor.Transparency = 1
    anchor.Massless = true
    anchor.CanCollide = false
    anchor.CanQuery = false
    anchor.CanTouch = false
    anchor.CastShadow = false
    anchor.CFrame = anchorPart.CFrame * spec.offset
    anchor.Parent = container

    local weld = Instance.new('WeldConstraint')
    weld.Part0 = anchorPart
    weld.Part1 = anchor
    weld.Parent = anchor

    local attachment = Instance.new('Attachment')
    attachment.Parent = anchor

    local emitter = Instance.new('ParticleEmitter')
    emitter.Name = spec.name .. 'Emitter'
    emitter.Texture = spec.texture or 'rbxasset://textures/particles/sparkles_main.dds'
    emitter.Color = spec.color
    emitter.LightEmission = spec.lightEmission or 0.7
    emitter.Brightness = spec.brightness or 2
    emitter.Lifetime = spec.lifetime or NumberRange.new(0.8, 1.4)
    emitter.Rate = spec.rate or 18
    emitter.Speed = spec.speed or NumberRange.new(0.5, 1.8)
    emitter.Acceleration = spec.acceleration or Vector3.new(0, 1.2, 0)
    emitter.SpreadAngle = spec.spreadAngle or Vector2.new(30, 30)
    emitter.RotSpeed = spec.rotSpeed or NumberRange.new(-40, 40)
    emitter.Size = spec.size or NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.16),
        NumberSequenceKeypoint.new(1, 0.02),
    })
    emitter.Transparency = spec.transparency or NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.15),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Parent = attachment

    return anchor
end

local function buildCardAuraVisual(container, rigParts, auraPreset: string)
    if auraPreset == 'poring_bubbles' then
        createParticleAura(container, rigParts, {
            name = 'PoringBubbleAura',
            anchor = 'head',
            offset = CFrame.new(0, 0.15, 0),
            color = ColorSequence.new(Color3.fromRGB(255, 197, 222), Color3.fromRGB(255, 244, 250)),
            rate = 16,
            speed = NumberRange.new(0.25, 0.8),
            spreadAngle = Vector2.new(50, 50),
            size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.22),
                NumberSequenceKeypoint.new(1, 0.06),
            }),
        })
    elseif auraPreset == 'moon_hop' then
        createParticleAura(container, rigParts, {
            name = 'LunaticMoonAura',
            anchor = 'torso',
            offset = CFrame.new(0, 0.4, 0),
            color = ColorSequence.new(Color3.fromRGB(255, 251, 235), Color3.fromRGB(220, 228, 255)),
            rate = 12,
            speed = NumberRange.new(0.2, 0.7),
            spreadAngle = Vector2.new(42, 42),
        })
    elseif auraPreset == 'willow_spores' then
        createParticleAura(container, rigParts, {
            name = 'WillowSporeAura',
            anchor = 'torso',
            offset = CFrame.new(0, 0.3, 0),
            color = ColorSequence.new(Color3.fromRGB(144, 227, 142), Color3.fromRGB(89, 178, 103)),
            rate = 20,
            speed = NumberRange.new(0.15, 0.55),
            acceleration = Vector3.new(0, 0.9, 0),
            spreadAngle = Vector2.new(65, 65),
        })
    elseif auraPreset == 'rocker_rhythm' then
        createParticleAura(container, rigParts, {
            name = 'RockerRhythmAura',
            anchor = 'torso',
            offset = CFrame.new(0, 0.45, 0),
            color = ColorSequence.new(Color3.fromRGB(163, 255, 116), Color3.fromRGB(82, 233, 122)),
            rate = 24,
            speed = NumberRange.new(0.45, 1.2),
            spreadAngle = Vector2.new(90, 90),
        })
    elseif auraPreset == 'andre_crimson' then
        createParticleAura(container, rigParts, {
            name = 'AndreCrimsonAura',
            anchor = 'torso',
            offset = CFrame.new(0, 0.25, 0),
            color = ColorSequence.new(Color3.fromRGB(236, 88, 88), Color3.fromRGB(156, 49, 49)),
            rate = 18,
            speed = NumberRange.new(0.2, 0.75),
            spreadAngle = Vector2.new(52, 52),
        })
    elseif auraPreset == 'amber_shell' then
        createParticleAura(container, rigParts, {
            name = 'DeniroShellAura',
            anchor = 'torso',
            offset = CFrame.new(0, 0.15, 0),
            color = ColorSequence.new(Color3.fromRGB(255, 200, 118), Color3.fromRGB(191, 122, 54)),
            rate = 14,
            speed = NumberRange.new(0.08, 0.3),
            spreadAngle = Vector2.new(35, 35),
        })
    elseif auraPreset == 'precision_gleam' then
        createParticleAura(container, rigParts, {
            name = 'PierePrecisionAura',
            anchor = 'head',
            offset = CFrame.new(0, 0.05, 0),
            color = ColorSequence.new(Color3.fromRGB(255, 235, 168), Color3.fromRGB(255, 190, 98)),
            rate = 18,
            speed = NumberRange.new(0.55, 1.4),
            spreadAngle = Vector2.new(26, 26),
        })
    elseif auraPreset == 'honey_glow' then
        createParticleAura(container, rigParts, {
            name = 'VitataHoneyAura',
            anchor = 'torso',
            offset = CFrame.new(0, 0.4, 0),
            color = ColorSequence.new(Color3.fromRGB(255, 220, 128), Color3.fromRGB(255, 174, 76)),
            rate = 20,
            speed = NumberRange.new(0.18, 0.48),
            spreadAngle = Vector2.new(48, 48),
        })
    elseif auraPreset == 'shadow_veil' then
        createParticleAura(container, rigParts, {
            name = 'MayaShadowAura',
            anchor = 'torso',
            offset = CFrame.new(0, 0.45, 0),
            color = ColorSequence.new(Color3.fromRGB(182, 120, 255), Color3.fromRGB(74, 48, 126)),
            rate = 24,
            speed = NumberRange.new(0.12, 0.4),
            spreadAngle = Vector2.new(70, 70),
        })
    elseif auraPreset == 'murmur_shroud' then
        createParticleAura(container, rigParts, {
            name = 'MurmurShroudAura',
            anchor = 'torso',
            offset = CFrame.new(0, 0.3, 0),
            color = ColorSequence.new(Color3.fromRGB(130, 107, 162), Color3.fromRGB(60, 54, 88)),
            rate = 16,
            speed = NumberRange.new(0.16, 0.42),
            spreadAngle = Vector2.new(68, 68),
        })
    elseif auraPreset == 'toy_starlight' then
        createParticleAura(container, rigParts, {
            name = 'LudeToyAura',
            anchor = 'head',
            offset = CFrame.new(0, 0.1, 0),
            color = ColorSequence.new(Color3.fromRGB(255, 220, 132), Color3.fromRGB(255, 172, 118)),
            rate = 18,
            speed = NumberRange.new(0.25, 0.8),
            spreadAngle = Vector2.new(42, 42),
        })
    elseif auraPreset == 'mourning_satin' then
        createParticleAura(container, rigParts, {
            name = 'QuveRibbonAura',
            anchor = 'torso',
            offset = CFrame.new(0, 0.35, 0),
            color = ColorSequence.new(Color3.fromRGB(224, 214, 255), Color3.fromRGB(132, 116, 176)),
            rate = 16,
            speed = NumberRange.new(0.12, 0.5),
            spreadAngle = Vector2.new(52, 52),
        })
    elseif auraPreset == 'puppet_strings' then
        createParticleAura(container, rigParts, {
            name = 'HylozoistStringAura',
            anchor = 'torso',
            offset = CFrame.new(0, 0.3, 0),
            color = ColorSequence.new(Color3.fromRGB(170, 152, 216), Color3.fromRGB(102, 90, 138)),
            rate = 22,
            speed = NumberRange.new(0.1, 0.34),
            spreadAngle = Vector2.new(70, 70),
        })
    elseif auraPreset == 'gibbet_chains' then
        createParticleAura(container, rigParts, {
            name = 'GibbetChainAura',
            anchor = 'torso',
            offset = CFrame.new(0, 0.25, 0),
            color = ColorSequence.new(Color3.fromRGB(188, 198, 222), Color3.fromRGB(98, 104, 124)),
            rate = 14,
            speed = NumberRange.new(0.16, 0.45),
            spreadAngle = Vector2.new(48, 48),
        })
    elseif auraPreset == 'nightflame_helm' then
        createParticleAura(container, rigParts, {
            name = 'DullahanFlameAura',
            anchor = 'head',
            offset = CFrame.new(0, 0.05, 0),
            color = ColorSequence.new(Color3.fromRGB(132, 184, 255), Color3.fromRGB(72, 112, 206)),
            rate = 18,
            speed = NumberRange.new(0.22, 0.66),
            spreadAngle = Vector2.new(36, 36),
        })
    elseif auraPreset == 'phantom_shroud' then
        createParticleAura(container, rigParts, {
            name = 'DisguisePhantomAura',
            anchor = 'torso',
            offset = CFrame.new(0, 0.42, 0),
            color = ColorSequence.new(Color3.fromRGB(240, 244, 255), Color3.fromRGB(158, 170, 210)),
            rate = 12,
            speed = NumberRange.new(0.08, 0.24),
            spreadAngle = Vector2.new(78, 78),
        })
    elseif auraPreset == 'bloody_slash' then
        createParticleAura(container, rigParts, {
            name = 'BloodySlashAura',
            anchor = 'torso',
            offset = CFrame.new(0, 0.2, 0),
            color = ColorSequence.new(Color3.fromRGB(255, 104, 116), Color3.fromRGB(138, 40, 56)),
            rate = 20,
            speed = NumberRange.new(0.45, 1.1),
            spreadAngle = Vector2.new(30, 30),
        })
    elseif auraPreset == 'ruri_petals' then
        createParticleAura(container, rigParts, {
            name = 'LoliRuriPetalAura',
            anchor = 'torso',
            offset = CFrame.new(0, 0.38, 0),
            color = ColorSequence.new(Color3.fromRGB(255, 206, 232), Color3.fromRGB(216, 138, 194)),
            rate = 18,
            speed = NumberRange.new(0.1, 0.36),
            spreadAngle = Vector2.new(64, 64),
        })
    elseif auraPreset == 'reaper_wisps' then
        createParticleAura(container, rigParts, {
            name = 'LordOfDeadAura',
            anchor = 'torso',
            offset = CFrame.new(0, 0.46, 0),
            color = ColorSequence.new(Color3.fromRGB(186, 208, 255), Color3.fromRGB(110, 118, 168)),
            rate = 24,
            speed = NumberRange.new(0.14, 0.42),
            spreadAngle = Vector2.new(82, 82),
        })
    end
end

local function buildKnightVisuals(container, rigParts)
    local steel = Color3.fromRGB(92, 99, 112)
    local gold = Color3.fromRGB(214, 182, 92)
    local crimson = Color3.fromRGB(146, 52, 52)

    attachVisualPart(container, rigParts, {
        name = 'KnightChestplate',
        anchor = 'torso',
        size = Vector3.new(2.5, 2.35, 1.12),
        offset = CFrame.new(0, 0, 0.08),
        color = steel,
        material = Enum.Material.Metal,
    })
    attachVisualPart(container, rigParts, {
        name = 'KnightCape',
        anchor = 'torso',
        size = Vector3.new(2.25, 2.65, 0.2),
        offset = CFrame.new(0, -0.12, 0.72),
        color = crimson,
        material = Enum.Material.Fabric,
    })
    attachVisualPart(container, rigParts, {
        name = 'KnightLeftPauldron',
        anchor = 'leftUpperArm',
        size = Vector3.new(1.15, 0.6, 1.15),
        offset = CFrame.new(0, -0.3, 0),
        color = gold,
        material = Enum.Material.Metal,
    })
    attachVisualPart(container, rigParts, {
        name = 'KnightRightPauldron',
        anchor = 'rightUpperArm',
        size = Vector3.new(1.15, 0.6, 1.15),
        offset = CFrame.new(0, -0.3, 0),
        color = gold,
        material = Enum.Material.Metal,
    })
    attachVisualPart(container, rigParts, {
        name = 'KnightShield',
        anchor = 'leftLowerArm',
        size = Vector3.new(0.28, 1.85, 1.35),
        offset = CFrame.new(-0.52, 0, 0),
        color = steel,
        material = Enum.Material.Metal,
    })
end

local function buildMageVisuals(container, rigParts)
    local cloth = Color3.fromRGB(64, 53, 118)
    local arcane = Color3.fromRGB(101, 219, 255)
    local pale = Color3.fromRGB(218, 228, 255)

    attachVisualPart(container, rigParts, {
        name = 'MageMantle',
        anchor = 'torso',
        size = Vector3.new(2.45, 2.85, 1.2),
        offset = CFrame.new(0, -0.08, 0.02),
        color = cloth,
        material = Enum.Material.Fabric,
    })
    attachVisualPart(container, rigParts, {
        name = 'MageHatBrim',
        anchor = 'head',
        size = Vector3.new(1.7, 0.18, 1.7),
        offset = CFrame.new(0, 0.42, 0),
        color = Color3.fromRGB(56, 44, 106),
        material = Enum.Material.SmoothPlastic,
    })
    attachVisualPart(container, rigParts, {
        name = 'MageHatCrown',
        anchor = 'head',
        size = Vector3.new(1.08, 0.92, 1.08),
        offset = CFrame.new(0, 0.9, 0),
        color = cloth,
        material = Enum.Material.SmoothPlastic,
    })
    attachVisualPart(container, rigParts, {
        name = 'MageStaff',
        anchor = 'rightLowerArm',
        size = Vector3.new(0.2, 2.75, 0.2),
        offset = CFrame.new(0.52, -0.06, 0),
        color = Color3.fromRGB(130, 96, 61),
        material = Enum.Material.Wood,
    })
    attachVisualPart(container, rigParts, {
        name = 'MageGem',
        anchor = 'rightLowerArm',
        size = Vector3.new(0.48, 0.48, 0.48),
        offset = CFrame.new(0.52, 1.26, 0),
        color = arcane,
        material = Enum.Material.Neon,
        shape = Enum.PartType.Ball,
    })
    attachVisualPart(container, rigParts, {
        name = 'MageOrb',
        anchor = 'leftHand',
        size = Vector3.new(0.54, 0.54, 0.54),
        offset = CFrame.new(0, -0.2, -0.48),
        color = pale,
        material = Enum.Material.Neon,
        shape = Enum.PartType.Ball,
        transparency = 0.08,
    })
end

local function buildArcherVisuals(container, rigParts)
    local leather = Color3.fromRGB(96, 74, 46)
    local forest = Color3.fromRGB(70, 118, 74)
    local amber = Color3.fromRGB(214, 162, 79)

    attachVisualPart(container, rigParts, {
        name = 'ArcherVest',
        anchor = 'torso',
        size = Vector3.new(2.32, 2.5, 1.05),
        offset = CFrame.new(0, 0, 0.05),
        color = forest,
        material = Enum.Material.Fabric,
    })
    attachVisualPart(container, rigParts, {
        name = 'ArcherHood',
        anchor = 'head',
        size = Vector3.new(1.28, 1.15, 1.28),
        offset = CFrame.new(0, 0.34, 0.12),
        color = forest,
        material = Enum.Material.Fabric,
    })
    attachVisualPart(container, rigParts, {
        name = 'ArcherQuiver',
        anchor = 'torso',
        size = Vector3.new(0.6, 1.55, 0.62),
        offset = CFrame.new(-0.88, -0.08, 0.48),
        color = leather,
        material = Enum.Material.Wood,
    })
    attachVisualPart(container, rigParts, {
        name = 'ArcherBowGrip',
        anchor = 'leftLowerArm',
        size = Vector3.new(0.18, 2.05, 0.2),
        offset = CFrame.new(-0.52, 0.08, 0),
        color = leather,
        material = Enum.Material.Wood,
    })
    attachVisualPart(container, rigParts, {
        name = 'ArcherBowUpper',
        anchor = 'leftLowerArm',
        size = Vector3.new(0.18, 1.28, 0.18),
        offset = CFrame.new(-0.92, 0.66, 0),
        color = amber,
        material = Enum.Material.Wood,
    })
    attachVisualPart(container, rigParts, {
        name = 'ArcherBowLower',
        anchor = 'leftLowerArm',
        size = Vector3.new(0.18, 1.28, 0.18),
        offset = CFrame.new(-0.92, -0.66, 0),
        color = amber,
        material = Enum.Material.Wood,
    })
    attachVisualPart(container, rigParts, {
        name = 'ArcherBracer',
        anchor = 'rightLowerArm',
        size = Vector3.new(0.9, 1.05, 0.9),
        offset = CFrame.new(0, 0, 0),
        color = leather,
        material = Enum.Material.SmoothPlastic,
    })
end

local function buildAssassinVisuals(container, rigParts)
    local shadow = Color3.fromRGB(58, 56, 72)
    local crimson = Color3.fromRGB(166, 70, 96)
    local poison = Color3.fromRGB(118, 229, 148)
    local steel = Color3.fromRGB(208, 213, 224)

    attachVisualPart(container, rigParts, {
        name = 'AssassinMantle',
        anchor = 'torso',
        size = Vector3.new(2.32, 2.62, 1.08),
        offset = CFrame.new(0, -0.06, 0.04),
        color = shadow,
        material = Enum.Material.Fabric,
    })
    attachVisualPart(container, rigParts, {
        name = 'AssassinHood',
        anchor = 'head',
        size = Vector3.new(1.3, 1.1, 1.3),
        offset = CFrame.new(0, 0.34, 0.08),
        color = shadow,
        material = Enum.Material.Fabric,
    })
    attachVisualPart(container, rigParts, {
        name = 'AssassinScarf',
        anchor = 'torso',
        size = Vector3.new(2.08, 0.38, 0.88),
        offset = CFrame.new(0, 0.7, -0.38),
        color = crimson,
        material = Enum.Material.Fabric,
    })
    attachVisualPart(container, rigParts, {
        name = 'AssassinLeftKatar',
        anchor = 'leftLowerArm',
        size = Vector3.new(0.18, 1.76, 0.42),
        offset = CFrame.new(-0.48, -0.06, 0),
        color = steel,
        material = Enum.Material.Metal,
    })
    attachVisualPart(container, rigParts, {
        name = 'AssassinRightKatar',
        anchor = 'rightLowerArm',
        size = Vector3.new(0.18, 1.76, 0.42),
        offset = CFrame.new(0.48, -0.06, 0),
        color = steel,
        material = Enum.Material.Metal,
    })
    attachVisualPart(container, rigParts, {
        name = 'AssassinPoisonVial',
        anchor = 'rightHand',
        size = Vector3.new(0.28, 0.52, 0.28),
        offset = CFrame.new(0.18, -0.18, -0.36),
        color = poison,
        material = Enum.Material.Neon,
    })
end

local function buildZeroVisuals(container, rigParts)
    local silver = Color3.fromRGB(210, 222, 242)
    local cobalt = Color3.fromRGB(88, 132, 222)
    local azure = Color3.fromRGB(138, 226, 255)
    local obsidian = Color3.fromRGB(44, 48, 62)

    attachVisualPart(container, rigParts, {
        name = 'ZeroCoat',
        anchor = 'torso',
        size = Vector3.new(2.42, 2.74, 1.08),
        offset = CFrame.new(0, -0.04, 0.02),
        color = obsidian,
        material = Enum.Material.Fabric,
    })
    attachVisualPart(container, rigParts, {
        name = 'ZeroMantle',
        anchor = 'torso',
        size = Vector3.new(2.18, 2.22, 0.18),
        offset = CFrame.new(0, -0.04, 0.7),
        color = cobalt,
        material = Enum.Material.Fabric,
    })
    attachVisualPart(container, rigParts, {
        name = 'ZeroCrest',
        anchor = 'head',
        size = Vector3.new(0.86, 0.4, 0.86),
        offset = CFrame.new(0, 0.86, 0),
        color = azure,
        material = Enum.Material.Neon,
        transparency = 0.12,
    })
    attachVisualPart(container, rigParts, {
        name = 'ZeroLeftBlade',
        anchor = 'leftLowerArm',
        size = Vector3.new(0.18, 2.05, 0.34),
        offset = CFrame.new(-0.54, -0.08, 0),
        color = silver,
        material = Enum.Material.Metal,
    })
    attachVisualPart(container, rigParts, {
        name = 'ZeroRightBlade',
        anchor = 'rightLowerArm',
        size = Vector3.new(0.18, 2.18, 0.34),
        offset = CFrame.new(0.54, -0.04, 0),
        color = silver,
        material = Enum.Material.Metal,
    })
    attachVisualPart(container, rigParts, {
        name = 'ZeroLeftEdge',
        anchor = 'leftLowerArm',
        size = Vector3.new(0.08, 2.12, 0.18),
        offset = CFrame.new(-0.56, -0.06, -0.18),
        color = azure,
        material = Enum.Material.Neon,
        transparency = 0.18,
    })
    attachVisualPart(container, rigParts, {
        name = 'ZeroRightEdge',
        anchor = 'rightLowerArm',
        size = Vector3.new(0.08, 2.24, 0.18),
        offset = CFrame.new(0.56, -0.02, -0.18),
        color = azure,
        material = Enum.Material.Neon,
        transparency = 0.18,
    })
    createParticleAura(container, rigParts, {
        name = 'ZeroAfterglow',
        anchor = 'torso',
        offset = CFrame.new(0, 0.24, 0),
        color = ColorSequence.new(azure, cobalt),
        rate = 8,
        speed = NumberRange.new(0.12, 0.34),
        spreadAngle = Vector2.new(36, 36),
        size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.08),
            NumberSequenceKeypoint.new(1, 0),
        }),
    })
end

local function buildPoringHatVisuals(container, rigParts)
    local poringPink = Color3.fromRGB(255, 183, 214)
    local poringShadow = Color3.fromRGB(236, 146, 191)
    local poringEye = Color3.fromRGB(48, 29, 54)

    attachVisualPart(container, rigParts, {
        name = 'PoringHatBlob',
        anchor = 'head',
        size = Vector3.new(1.46, 0.9, 1.38),
        offset = CFrame.new(0, 0.76, 0.02),
        color = poringPink,
        material = Enum.Material.SmoothPlastic,
    })
    attachVisualPart(container, rigParts, {
        name = 'PoringHatDrapeLeft',
        anchor = 'head',
        size = Vector3.new(0.34, 0.54, 0.34),
        offset = CFrame.new(-0.42, 0.5, 0.12),
        color = poringShadow,
        material = Enum.Material.SmoothPlastic,
    })
    attachVisualPart(container, rigParts, {
        name = 'PoringHatDrapeRight',
        anchor = 'head',
        size = Vector3.new(0.34, 0.54, 0.34),
        offset = CFrame.new(0.42, 0.5, 0.12),
        color = poringShadow,
        material = Enum.Material.SmoothPlastic,
    })
    attachVisualPart(container, rigParts, {
        name = 'PoringHatEyeLeft',
        anchor = 'head',
        size = Vector3.new(0.08, 0.08, 0.08),
        offset = CFrame.new(-0.16, 0.76, -0.66),
        color = poringEye,
        material = Enum.Material.SmoothPlastic,
        shape = Enum.PartType.Ball,
    })
    attachVisualPart(container, rigParts, {
        name = 'PoringHatEyeRight',
        anchor = 'head',
        size = Vector3.new(0.08, 0.08, 0.08),
        offset = CFrame.new(0.16, 0.76, -0.66),
        color = poringEye,
        material = Enum.Material.SmoothPlastic,
        shape = Enum.PartType.Ball,
    })
end

local function ensureArchetypeVisuals(player, archetypeId: string)
    local character = player.Character
    if not character then
        return
    end

    local existing = character:FindFirstChild(ARCHETYPE_VISUALS_FOLDER_NAME)
    if existing and existing:GetAttribute('ArchetypeId') == archetypeId and #existing:GetChildren() > 0 then
        return
    end
    if existing then
        existing:Destroy()
    end

    local rigParts = buildRigPartMap(character)
    if not rigParts.head or not rigParts.torso then
        return
    end

    local container = Instance.new('Folder')
    container.Name = ARCHETYPE_VISUALS_FOLDER_NAME
    container:SetAttribute('ArchetypeId', archetypeId)
    container.Parent = character

    if archetypeId == 'knight_path' then
        buildKnightVisuals(container, rigParts)
    elseif archetypeId == 'assassin_path' then
        buildAssassinVisuals(container, rigParts)
    elseif archetypeId == 'mage_path' then
        buildMageVisuals(container, rigParts)
    elseif archetypeId == 'archer_path' then
        buildArcherVisuals(container, rigParts)
    elseif archetypeId == 'zero_path' then
        buildZeroVisuals(container, rigParts)
    end
end

local function getEquippedItemInstance(player, slotName: string)
    local instanceId = InventoryService.getEquippedInstanceId(player, slotName)
    if not instanceId then
        return nil
    end

    return InventoryService.getAllItemInstances(player)[instanceId]
end

local function getEquippedSocketedCardDefs(player)
    local cardDefs = {}
    local seen = {}
    for _, instanceId in pairs(PlayerDataService.getOrCreateProfile(player).equipment) do
        if instanceId then
            local itemInstance = InventoryService.getEnhanceableItem(player, instanceId)
            if itemInstance and not itemInstance.destroyed then
                for _, cardId in ipairs(itemInstance.socketedCards or {}) do
                    if not seen[cardId] then
                        seen[cardId] = true
                        local cardDef = CardDefs[cardId]
                        if cardDef then
                            table.insert(cardDefs, cardDef)
                        end
                    end
                end
            end
        end
    end
    return cardDefs
end

local function ensureEquipmentVisuals(player)
    local character = player.Character
    if not character then
        return
    end

    local equippedHeadTop = getEquippedItemInstance(player, 'HeadTop')
    local equippedWeapon = getEquippedItemInstance(player, 'Weapon')
    local equippedCardDefs = getEquippedSocketedCardDefs(player)
    local auraTokens = {}
    for _, cardDef in ipairs(equippedCardDefs) do
        if type(cardDef.auraPreset) == 'string' and cardDef.auraPreset ~= '' then
            table.insert(auraTokens, cardDef.auraPreset)
        end
    end
    table.sort(auraTokens)
    local visualSignature = table.concat({
        equippedHeadTop and equippedHeadTop.itemId or '',
        equippedWeapon and equippedWeapon.itemId or '',
        table.concat(auraTokens, ','),
    }, '|')
    local existing = character:FindFirstChild(EQUIPMENT_VISUALS_FOLDER_NAME)
    if existing and existing:GetAttribute('VisualSignature') == visualSignature and #existing:GetChildren() > 0 then
        return
    end
    if existing then
        existing:Destroy()
    end
    if visualSignature == '|' then
        return
    end

    local rigParts = buildRigPartMap(character)
    if not rigParts.head then
        return
    end

    local container = Instance.new('Folder')
    container.Name = EQUIPMENT_VISUALS_FOLDER_NAME
    container:SetAttribute('VisualSignature', visualSignature)
    container.Parent = character

    if equippedHeadTop and equippedHeadTop.itemId == 'poring_hood' then
        buildPoringHatVisuals(container, rigParts)
    end

    if equippedWeapon then
        buildWeaponVisual(container, rigParts, equippedWeapon.itemId)
    end

    for _, cardDef in ipairs(equippedCardDefs) do
        if type(cardDef.auraPreset) == 'string' and cardDef.auraPreset ~= '' then
            buildCardAuraVisual(container, rigParts, cardDef.auraPreset)
        end
    end
end

local function updateCharacterStats(player)
    local humanoid = getCharacterHumanoid(player)
    if not humanoid then
        return
    end

    local stats = StatService.getDerivedStats(player)
    local currentWeight = InventoryService.getCurrentWeight(player)
    local weightRatio = currentWeight / math.max(stats.carryWeight, 1)

    local previousMaxHealth = humanoid.MaxHealth
    humanoid.MaxHealth = stats.maxHealth
    humanoid.Health = math.min(if previousMaxHealth > 0 then humanoid.Health * (stats.maxHealth / previousMaxHealth) else stats.maxHealth, stats.maxHealth)

    if weightRatio >= 1 then
        humanoid.WalkSpeed = 4
    elseif weightRatio >= 0.9 then
        humanoid.WalkSpeed = 8
    elseif weightRatio >= 0.5 then
        humanoid.WalkSpeed = 14
    else
        humanoid.WalkSpeed = 16
    end

    local profile = PlayerDataService.getOrCreateProfile(player)
    if PlayerDataService.isAdminPowerEnabled(player) then
        profile.runtime.currentMana = stats.maxMana
    elseif profile.runtime.currentMana == nil then
        profile.runtime.currentMana = stats.maxMana
    else
        profile.runtime.currentMana = math.clamp(profile.runtime.currentMana, 0, stats.maxMana)
    end

    ensureArchetypeVisuals(player, profile.archetypeId)
    ensureEquipmentVisuals(player)
end

local function applyNaturalRegen(player)
    local humanoid = getCharacterHumanoid(player)
    if not humanoid then
        return
    end

    local stats = StatService.getDerivedStats(player)
    local profile = PlayerDataService.getOrCreateProfile(player)
    if PlayerDataService.isAdminPowerEnabled(player) then
        profile.runtime.currentMana = stats.maxMana
        return
    end

    local regenMultiplier = if humanoid.Sit then 2 else 1

    humanoid.Health = math.min(humanoid.Health + stats.hpRegenPerTick * regenMultiplier, humanoid.MaxHealth)
    profile.runtime.currentMana = math.min((profile.runtime.currentMana or stats.maxMana) + stats.spRegenPerTick * regenMultiplier, stats.maxMana)
end

local function healPlayer(player)
    local humanoid = getCharacterHumanoid(player)
    if humanoid then
        updateCharacterStats(player)
        humanoid.Health = humanoid.MaxHealth
    end

    PlayerDataService.fullHeal(player)
    PlayerDataService.getOrCreateProfile(player).runtime.currentMana = StatService.getDerivedStats(player).maxMana
end

local function useInventoryItem(player, itemId: string): (boolean, string)
    local itemDef = ItemDefs[itemId]
    if not itemDef then
        return false, 'Unknown item.'
    end
    if itemDef.itemType ~= 'Consumable' then
        return false, 'That item cannot be used from the bag.'
    end
    if InventoryService.getInventoryAmount(player, itemId) <= 0 then
        return false, 'You do not have that item anymore.'
    end

    local profile = PlayerDataService.getOrCreateProfile(player)
    local humanoid = getCharacterHumanoid(player)
    local rootPart = player.Character and player.Character:FindFirstChild('HumanoidRootPart')
    local stats = StatService.getDerivedStats(player)

    local isAmmoItem = false
    for _, tag in ipairs(itemDef.tags or {}) do
        if tag == 'ammo' then
            isAmmoItem = true
            break
        end
    end
    if isAmmoItem then
        local ok, reason = InventoryService.equipAmmoItem(player, itemId)
        if ok then
            return true, string.format('Equipped %s.', itemDef.name)
        end
        return false, tostring(reason)
    end

    local function consumeOne()
        InventoryService.consumeConsumable(player, itemId, 1)
    end

    local function healHealth(amount: number)
        if not humanoid then
            return false, 'No character to heal.'
        end

        consumeOne()
        humanoid.Health = math.min(humanoid.Health + amount, humanoid.MaxHealth)
        return true, string.format('Used %s.', itemDef.name)
    end

    local function healMana(amount: number)
        consumeOne()
        profile.runtime.currentMana = math.min((profile.runtime.currentMana or stats.maxMana) + amount, stats.maxMana)
        return true, string.format('Used %s.', itemDef.name)
    end

    if itemId == 'red_potion' then
        return healHealth(45)
    elseif itemId == 'apple' then
        return healHealth(22)
    elseif itemId == 'green_herb' then
        return healHealth(20)
    elseif itemId == 'yellow_herb' then
        return healHealth(45)
    elseif itemId == 'honey' then
        return healHealth(80)
    elseif itemId == 'royal_jelly' then
        return healHealth(160)
    elseif itemId == 'orange_potion' then
        return healHealth(105)
    elseif itemId == 'yellow_potion' then
        return healHealth(175)
    elseif itemId == 'blue_potion' then
        return healMana(80)
    elseif itemId == 'fly_wing' then
        if not rootPart then
            return false, 'No character to warp.'
        end

        consumeOne()
        local zoneId = profile.runtime.lastZoneId or 'prontera_field'
        local baseCFrame = if zoneId == 'ant_hell_floor_1'
            then WorldService.getDungeonSpawnCFrame('ant_hell_floor_1')
            else WorldService.getFieldSpawnCFrame()
        local scatter = if zoneId == 'ant_hell_floor_1'
            then Vector3.new(math.random(-60, 60), 0, math.random(-60, 60))
            else Vector3.new(math.random(-120, 120), 0, math.random(-70, 70))
        rootPart.CFrame = baseCFrame + scatter
        profile.runtime.lastZoneId = zoneId
        return true, 'Fly Wing warped you to a nearby spot.'
    elseif itemId == 'butterfly_wing' then
        if not rootPart then
            return false, 'No character to warp.'
        end

        consumeOne()
        rootPart.CFrame = WorldService.getTownSpawnCFrame()
        profile.runtime.lastZoneId = 'zoltraak'
        return true, 'Butterfly Wing returned you to town.'
    end

    return false, string.format('%s is not wired for quick-use yet.', itemDef.name)
end

local function getClassRequirementsText(profile)
    local classDef = ClassStageDefs[profile.classId]
    local nextClassId = PlayerDataService.getNextClassId(profile)
    local nextText = nextClassId and ClassStageDefs[nextClassId].displayName or 'No further class'
    local currentRequirement = classDef and classDef.promotionLevel or 0

    return string.format(
        'Current: %s | Job Lv %d/%d | Next: %s | Rebirth Count: %d',
        profile.classId,
        profile.jobLevel,
        currentRequirement,
        nextText,
        profile.rebirthCount
    )
end

local function getGameState(player)
    local profile = PlayerDataService.getOrCreateProfile(player)
    local stats = StatService.getDerivedStats(player)
    local itemInstances = {}

    for instanceId, item in pairs(InventoryService.getAllItemInstances(player)) do
        if not item.destroyed then
            itemInstances[instanceId] = {
                instanceId = item.instanceId,
                itemId = item.itemId,
                slot = item.slot,
                enhancementLevel = item.enhancementLevel,
                enhancementTrack = item.enhancementTrack,
                rarity = item.rarity,
                affixes = item.affixes,
                socketedCards = item.socketedCards,
                sourceMonsterId = item.sourceMonsterId,
                sourceHint = item.sourceHint,
            }
        end
    end

    local dungeons = {}
    for dungeonId, dungeonDef in pairs(Dungeons) do
        table.insert(dungeons, {
            id = dungeonId,
            name = dungeonDef.name,
            recommendedLevel = dungeonDef.recommendedLevel,
        })
    end

      return {
        isAdmin = AdminConfig.isPlayerAuthorized(player),
          profile = {
            level = profile.level,
            experience = profile.experience,
            jobLevel = profile.jobLevel,
            jobExperience = profile.jobExperience,
            statPoints = profile.statPoints,
            skillPoints = profile.skillPoints,
            zeny = profile.zeny,
            classId = profile.classId,
            classStage = profile.classStage,
            archetypeId = profile.archetypeId,
            rebirthCount = profile.rebirthCount,
            baseStats = profile.baseStats,
            inventory = profile.inventory,
            cards = profile.cards,
            equipment = profile.equipment,
            settings = profile.settings,
            runtime = profile.runtime,
            grantedSkills = SkillLoadout.getGrantedSkills(profile),
            currentWeight = InventoryService.getCurrentWeight(player),
            requiredBaseExperience = PlayerDataService.getRequiredBaseExperience(profile.level),
            requiredJobExperience = PlayerDataService.getRequiredJobExperience(profile.jobLevel),
          },
          derivedStats = stats,
          statPreviewContext = StatService.getPreviewContext(player),
          itemInstances = itemInstances,
        enemies = EnemyService.getState(),
        dungeons = dungeons,
        classes = ArchetypeDefs,
        unlockedSkills = SkillLoadout.getUnlockedSkills(profile),
        availableSkills = SkillLoadout.getArchetypeSkillCatalog(profile),
        skillRanks = SkillLoadout.getResolvedSkillRanks(profile),
        skillUiState = SkillLoadout.getSkillUiState(profile),
        hotbarSlots = SkillLoadout.getResolvedHotbar(profile),
        archetypeProgression = PlayerDataService.getArchetypeProgressionSummary(player),
        party = PartyService.getPartyStateForPlayer(player),
        requirementText = getClassRequirementsText(profile),
    }
end

local function pushState(player)
    if player.Character then
        updateCharacterStats(player)
    end
    events.StateUpdated:FireClient(player, getGameState(player))
end

local function showMessage(player, payload)
    events.UiMessage:FireClient(player, payload)
end

local function broadcastBossWindUp(payload)
    for _, recipient in ipairs(Players:GetPlayers()) do
        events.BossWindUp:FireClient(recipient, payload)
    end
end

local function broadcastParryResult(player, payload)
    if player then
        events.ParryResult:FireClient(player, payload)
    end
end

local function sendChatPayload(recipients, payload)
    for _, recipient in ipairs(recipients) do
        events.ChatMessageReceived:FireClient(recipient, payload)
    end
end

local function normalizeChatChannel(channel: string?): string
    return string.lower(tostring(channel or 'local')) == 'party' and 'Party' or 'Local'
end

local function sendSystemChat(player, channel: string?, text: string)
    sendChatPayload({ player }, {
        channel = normalizeChatChannel(channel),
        senderUserId = 0,
        senderName = 'System',
        text = text,
        sentAt = os.time(),
    })
end

local function broadcastSystemChat(channel: string?, text: string)
    local recipients = Players:GetPlayers()
    if #recipients == 0 then
        return
    end

    sendChatPayload(recipients, {
        channel = normalizeChatChannel(channel),
        senderUserId = 0,
        senderName = 'System',
        text = text,
        sentAt = os.time(),
    })
end

local function sendSystemChatLines(player, channel: string?, lines)
    for _, line in ipairs(lines) do
        sendSystemChat(player, channel, line)
    end
end

local function findPlayerByName(username: string)
    local normalizedTarget = string.lower(username)
    for _, candidate in ipairs(Players:GetPlayers()) do
        if string.lower(candidate.Name) == normalizedTarget then
            return candidate
        end
    end

    return nil
end

local function tokenizeCommand(text: string)
    local tokens = {}
    for token in string.gmatch(text, '%S+') do
        table.insert(tokens, token)
    end
    return tokens
end

local function warpPlayerToTown(player)
    return DungeonService.warpPlayerToZone(player, 'zoltraak')
end

local function getWarpCommandLines(commandName: string): { string }
    local lines = {}
    for _, destination in ipairs(WorldService.getWarpDestinations()) do
        local segments = {}
        if destination.number then
            table.insert(segments, string.format('%s %d', commandName, destination.number))
        end
        if destination.primaryAlias ~= '' then
            table.insert(segments, string.format('%s %s', commandName, destination.primaryAlias))
        end
        if #segments == 0 then
            table.insert(segments, string.format('%s %s', commandName, string.lower(destination.displayName)))
        end
        table.insert(lines, string.format('%s (%s)', table.concat(segments, ' | '), destination.displayName))
    end
    return lines
end

local function buildShopPayload(shopId: string)
    local shopDef = ShopDefs[shopId]
    if not shopDef then
        return nil
    end

    local buyItems = {}
    for _, itemId in ipairs(shopDef.buyItems) do
        local itemDef = ItemDefs[itemId]
        if itemDef then
            table.insert(buyItems, {
                itemId = itemId,
                name = itemDef.name,
                buyPrice = itemDef.buyPrice or 0,
                sellPrice = itemDef.sellPrice or 0,
                itemType = itemDef.itemType,
            })
        end
    end

    return {
        shopId = shopDef.id,
        name = shopDef.name,
        buyItems = buyItems,
    }
end

local function playSkillEffect(player, effectPayload)
    if effectPayload then
        for _, recipient in ipairs(Players:GetPlayers()) do
            events.PlaySkillEffect:FireClient(recipient, effectPayload)
        end
    end
end

local function playCombatResultEffects(player, result)
    if type(result) ~= 'table' then
        return
    end

    playSkillEffect(player, result.effect)

    if result.hits then
        for _, hit in ipairs(result.hits) do
            if type(hit) == 'table' then
                playCombatResultEffects(player, hit)
            end
        end
    end
end

local function collectLevelUpSummary(result, summary)
    summary = summary or {
        baseLevelsGained = 0,
        jobLevelsGained = 0,
        didBaseLevelUp = false,
        didJobLevelUp = false,
        didAnyLevelUp = false,
    }

    if type(result) ~= 'table' then
        return summary
    end

    local levelUp = result.levelUp or (result.killRewards and result.killRewards.levelUp) or nil
    if type(levelUp) == 'table' then
        summary.baseLevelsGained += levelUp.baseLevelsGained or 0
        summary.jobLevelsGained += levelUp.jobLevelsGained or 0
    end

    for _, hit in ipairs(result.hits or {}) do
        if type(hit) == 'table' then
            collectLevelUpSummary(hit, summary)
        end
    end

    summary.didBaseLevelUp = summary.baseLevelsGained > 0
    summary.didJobLevelUp = summary.jobLevelsGained > 0
    summary.didAnyLevelUp = summary.didBaseLevelUp or summary.didJobLevelUp
    return summary
end

local function celebrateLevelUp(player, levelUpSummary)
    if type(levelUpSummary) ~= 'table' or levelUpSummary.didAnyLevelUp ~= true then
        return
    end

    healPlayer(player)

    local character = player.Character
    local rootPart = character and character:FindFirstChild('HumanoidRootPart')
    local head = character and character:FindFirstChild('Head')
    local focusPart = if head and head:IsA('BasePart') then head else rootPart
    local sourcePosition = if rootPart and rootPart:IsA('BasePart') then rootPart.Position else Vector3.zero
    local targetPosition = if focusPart and focusPart:IsA('BasePart') then focusPart.Position + Vector3.new(0, 1.5, 0) else sourcePosition
    local effectText = 'JOB UP!'
    if levelUpSummary.didBaseLevelUp and levelUpSummary.didJobLevelUp then
        effectText = 'LVL + JOB UP!'
    elseif levelUpSummary.didBaseLevelUp then
        effectText = 'LVL UP!'
    end

    local effectColor = if levelUpSummary.didBaseLevelUp
        then Color3.fromRGB(255, 220, 110)
        else Color3.fromRGB(142, 208, 255)

    playSkillEffect(player, {
        effectKey = 'level_up',
        style = 'levelUp',
        sourcePosition = sourcePosition,
        targetPosition = targetPosition,
        color = effectColor,
        attackerUserId = player.UserId,
        levelUpText = effectText,
        baseLevelsGained = levelUpSummary.baseLevelsGained or 0,
        jobLevelsGained = levelUpSummary.jobLevelsGained or 0,
    })

    if levelUpSummary.didBaseLevelUp and levelUpSummary.didJobLevelUp then
        showMessage(player, string.format('LVL UP! +%d Base Lv and +%d Job Lv. HP/SP REPLENISHED.', levelUpSummary.baseLevelsGained or 0, levelUpSummary.jobLevelsGained or 0))
    elseif levelUpSummary.didBaseLevelUp then
        showMessage(player, string.format('LVL UP! +%d Base Lv. HP/SP REPLENISHED.', levelUpSummary.baseLevelsGained or 0))
    else
        showMessage(player, string.format('JOB LEVEL UP! +%d Job Lv. HP/SP REPLENISHED.', levelUpSummary.jobLevelsGained or 0))
    end
end

local function handleChatCommand(player, channel: string?, rawText: string)
    if type(rawText) ~= 'string' then
        return false, false
    end

    local trimmed = rawText:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    local prefix = string.sub(trimmed, 1, 1)
    if prefix ~= '@' and prefix ~= '/' then
        return false, false
    end

    local args = tokenizeCommand(trimmed)
    local command = string.lower(args[1] or '')
    if string.sub(command, 1, 1) == '/' then
        command = '@' .. string.sub(command, 2)
    end
    local isAdmin = AdminConfig.isPlayerAuthorized(player)

    if command == '@help' then
        local lines = {
            'Commands:',
            '@help -> show this command list.',
            '@go -> list live map warps.',
            '@warp -> same as @go.',
            '@go <number or alias> -> warp to that map.',
            '@warp <number or alias> -> warp to that map.',
            '@where -> show your current zone.',
            '@heal -> fully restore your HP and SP.',
        }
        if isAdmin then
            table.insert(lines, '@admin list -> show current admin usernames.')
            table.insert(lines, '@admin add <username> -> grant admin privileges.')
            table.insert(lines, '@admin remove <username> -> revoke admin privileges.')
            table.insert(lines, '@level <amount> -> grant base levels to yourself.')
            table.insert(lines, '@job <amount> -> grant job levels to yourself.')
            table.insert(lines, '@maxstats -> max your base stats.')
            table.insert(lines, '@maxskills -> max your visible skills.')
        end
        sendSystemChatLines(player, channel, lines)
        return true, false
    end

    if command == '@where' then
        local profile = PlayerDataService.getOrCreateProfile(player)
        local rootPart = player.Character and player.Character:FindFirstChild('HumanoidRootPart')
        local zoneId = if rootPart and rootPart:IsA('BasePart')
            then WorldService.resolveZoneIdFromPosition(rootPart.Position, profile.runtime.lastZoneId)
            else tostring(profile.runtime.lastZoneId or 'unknown')
        sendSystemChat(player, channel, string.format('You are in %s (%s).', WorldService.getZoneDisplayName(zoneId), zoneId))
        return true, false
    end

    if command == '@go' or command == '@warp' then
        local destination = string.lower(args[2] or '')
        if destination == '' then
            local lines = { 'Warp destinations:' }
            for _, line in ipairs(getWarpCommandLines(command)) do
                table.insert(lines, line)
            end
            sendSystemChatLines(player, channel, lines)
            return true, false
        end

        local warpDestination = WorldService.getWarpDestination(destination)
        if not warpDestination then
            local lines = { 'Unknown warp. Try one of these:' }
            for _, line in ipairs(getWarpCommandLines(command)) do
                table.insert(lines, line)
            end
            sendSystemChatLines(player, channel, lines)
            return true, false
        end

        local ok, reason = DungeonService.warpPlayerToZone(player, warpDestination.zoneId)

        if ok then
            sendSystemChat(player, channel, string.format('Warped to %s.', warpDestination.displayName))
            return true, true
        end

        sendSystemChat(player, channel, 'Warp failed: ' .. tostring(reason))
        return true, false
    end

    if command == '@heal' then
        healPlayer(player)
        sendSystemChat(player, channel, 'Fully healed.')
        return true, true
    end

    if command == '@admin' then
        if not isAdmin then
            sendSystemChat(player, channel, 'Admin access denied.')
            return true, false
        end

        local subcommand = string.lower(args[2] or '')
        if subcommand == 'list' then
            local usernames = AdminConfig.getAuthorizedUsernames()
            sendSystemChat(player, channel, 'Admins: ' .. table.concat(usernames, ', '))
            return true, false
        end

        if subcommand == 'add' or subcommand == 'grant' then
            local username = args[3]
            if not username or username == '' then
                sendSystemChat(player, channel, 'Usage: @admin add <username>')
                return true, false
            end

            local okGrant, normalizedName = AdminConfig.grantUsername(username, player)
            if not okGrant then
                sendSystemChat(player, channel, if normalizedName == 'Unauthorized' then 'Admin access denied.' else 'Grant failed: ' .. tostring(normalizedName))
                return true, false
            end
            local targetPlayer = findPlayerByName(normalizedName)
            if targetPlayer then
                pushState(targetPlayer)
            end
            sendSystemChat(player, channel, string.format('Granted admin to %s.', normalizedName))
            return true, targetPlayer == player
        end

        if subcommand == 'remove' or subcommand == 'revoke' then
            local username = args[3]
            if not username or username == '' then
                sendSystemChat(player, channel, 'Usage: @admin remove <username>')
                return true, false
            end

            local okRevoke, normalizedName = AdminConfig.revokeUsername(username, player)
            if not okRevoke then
                sendSystemChat(player, channel, if normalizedName == 'Unauthorized' then 'Admin access denied.' else 'Revoke failed: ' .. tostring(normalizedName))
                return true, false
            end
            local targetPlayer = findPlayerByName(normalizedName)
            if targetPlayer then
                pushState(targetPlayer)
            end
            sendSystemChat(player, channel, string.format('Revoked admin from %s for this session.', normalizedName))
            return true, targetPlayer == player
        end

        sendSystemChatLines(player, channel, {
            'Admin commands:',
            '@admin list',
            '@admin add <username>',
            '@admin remove <username>',
        })
        return true, false
    end

    if command == '@level' or command == '@base' then
        if not isAdmin then
            sendSystemChat(player, channel, 'Admin access denied.')
            return true, false
        end

        local amount = math.max(math.floor(tonumber(args[2]) or 1), 1)
        local ok, reason, levelUpSummary = PlayerDataService.grantBaseLevels(player, amount)
        if not ok then
            sendSystemChat(player, channel, 'Base level update failed: ' .. tostring(reason))
            return true, false
        end

        celebrateLevelUp(player, levelUpSummary)
        return true, true
    end

    if command == '@job' then
        if not isAdmin then
            sendSystemChat(player, channel, 'Admin access denied.')
            return true, false
        end

        local amount = math.max(math.floor(tonumber(args[2]) or 1), 1)
        local ok, reason, levelUpSummary = PlayerDataService.grantJobLevels(player, amount)
        if not ok then
            sendSystemChat(player, channel, 'Job level update failed: ' .. tostring(reason))
            return true, false
        end

        celebrateLevelUp(player, levelUpSummary)
        return true, true
    end

    if command == '@maxstats' then
        if not isAdmin then
            sendSystemChat(player, channel, 'Admin access denied.')
            return true, false
        end

        PlayerDataService.maxAllBaseStats(player)
        sendSystemChat(player, channel, 'Base stats set to max.')
        return true, true
    end

    if command == '@maxskills' then
        if not isAdmin then
            sendSystemChat(player, channel, 'Admin access denied.')
            return true, false
        end

        PlayerDataService.maxAllAvailableSkills(player)
        sendSystemChat(player, channel, 'Visible skills set to max rank.')
        return true, true
    end

    sendSystemChat(player, channel, 'Unknown command. Type @help for the full list.')
    return true, false
end

local function handleBlacksmithPreview(player)
    local weaponInstanceId = InventoryService.getEquippedInstanceId(player, 'Weapon')
    if not weaponInstanceId then
        showMessage(player, 'Equip a weapon first.')
        return
    end

    local itemInstance = InventoryService.getEnhanceableItem(player, weaponInstanceId)
    if not itemInstance or not itemInstance.enhancementTrack then
        showMessage(player, 'This item cannot be enhanced.')
        return
    end

    local targetLevel = (itemInstance.enhancementLevel or 0) + 1
    if targetLevel > 10 then
        showMessage(player, 'This item is already at maximum enhancement.')
        return
    end

    local requirements = EnhancementFormula.getMaterialRequirements(itemInstance.enhancementTrack, targetLevel)
    local successRate = EnhancementFormula.getSuccessRate(itemInstance.enhancementTrack, targetLevel, StatService.getUpgradeLuckBonus(player))

    events.OpenBlacksmithMenu:FireClient(player, {
        itemInstanceId = itemInstance.instanceId,
        itemId = itemInstance.itemId,
        currentLevel = itemInstance.enhancementLevel,
        targetLevel = targetLevel,
        successRate = successRate,
        requirements = requirements,
    })
end

local function handleActionImpl(player, payload)
    if type(payload) ~= 'table' then
        return
    end

    -- Block all actions during parry stun (spec: no movement, no actions, no input for 0.5s)
    if CombatService.isParryStunned(player) then
        return
    end

    local action = payload.action
    local isAdmin = AdminConfig.isPlayerAuthorized(player)

    if action == GameplayNetDefs.Actions.AllocateStat then
        local ok, reason = PlayerDataService.allocateStat(player, payload.statName)
        if not ok then
            showMessage(player, 'Could not allocate stat: ' .. tostring(reason))
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.CommitStatDraft then
        local ok, reason = PlayerDataService.commitStatDraft(player, payload.draft)
        if not ok and reason ~= 'NoChanges' then
            showMessage(player, 'Could not save stats: ' .. tostring(reason))
        elseif ok then
            showMessage(player, 'Stat changes saved.')
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.InvestSkillPoint then
        local ok, reason = PlayerDataService.investSkillPoint(player, payload.skillId)
        if not ok then
            showMessage(player, 'Could not invest skill point: ' .. tostring(reason))
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.BasicAttackNearest then
        local ok, result = CombatService.basicAttackNearest(player)
        if ok and type(result) == 'table' then
            playCombatResultEffects(player, result)
            local levelUpSummary = collectLevelUpSummary(result)
            if levelUpSummary.didAnyLevelUp then
                celebrateLevelUp(player, levelUpSummary)
            elseif result.killRewards then
                showMessage(player, string.format('Defeated enemy. +%d zeny, +%d EXP', result.killRewards.zeny, result.killRewards.experience))
            elseif result.result == 'Miss' then
                showMessage(player, 'You missed.')
            end
        elseif not ok and result ~= 'AttackOnCooldown' then
            showMessage(player, 'Attack failed: ' .. tostring(result))
        end
        if ok then
            pushState(player)
        end
    elseif action == GameplayNetDefs.Actions.BasicAttackTarget then
        local ok, result = CombatService.basicAttackTarget(player, payload.enemyRuntimeId)
        if ok and type(result) == 'table' then
            playCombatResultEffects(player, result)
            local levelUpSummary = collectLevelUpSummary(result)
            if levelUpSummary.didAnyLevelUp then
                celebrateLevelUp(player, levelUpSummary)
            elseif result.killRewards then
                showMessage(player, string.format('Defeated enemy. +%d zeny, +%d EXP', result.killRewards.zeny, result.killRewards.experience))
            elseif result.result == 'Miss' then
                showMessage(player, 'Basic attack missed.')
            end
        elseif not ok and result ~= 'AttackOnCooldown' then
            showMessage(player, 'Attack failed: ' .. tostring(result))
        end
        if ok then
            pushState(player)
        end
    elseif action == GameplayNetDefs.Actions.EquipAmmoItem then
        local ok, reason = InventoryService.equipAmmoItem(player, tostring(payload.itemId or ''))
        if ok then
            local itemDef = ItemDefs[tostring(payload.itemId or '')]
            showMessage(player, string.format('Equipped %s.', itemDef and itemDef.name or tostring(payload.itemId)))
        else
            showMessage(player, 'Ammo equip failed: ' .. tostring(reason))
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.UseTargetedSkill then
        local ok, result = CombatService.useTargetedSkill(player, payload.skillId, payload.enemyRuntimeId, payload.targetPosition)
        if ok and type(result) == 'table' then
            local skillName = getSkillDisplayName(payload.skillId)
            playCombatResultEffects(player, result)
            local levelUpSummary = collectLevelUpSummary(result)
            if levelUpSummary.didAnyLevelUp then
                celebrateLevelUp(player, levelUpSummary)
            elseif result.message then
                showMessage(player, result.message)
            elseif result.killRewards then
                showMessage(player, string.format('%s landed. Enemy defeated.', skillName))
            elseif result.result == 'Miss' then
                showMessage(player, skillName .. ' missed.')
            elseif result.result == 'TargetArea' then
                local hitCount = #(result.hits or {})
                showMessage(player, string.format('%s hit %d target(s) for %d total damage.', skillName, hitCount, result.totalDamage or 0))
            elseif result.totalDamage then
                showMessage(player, string.format('%s dealt %d total damage.', skillName, result.totalDamage))
            else
                showMessage(player, string.format('%s hit for %d damage.', skillName, result.damage or 0))
            end
        elseif not ok then
            showMessage(player, 'Skill failed: ' .. tostring(result))
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.UseSplashSkill then
        local ok, result = CombatService.useSplashSkill(player, payload.skillId)
        if ok and type(result) == 'table' then
            local skillName = getSkillDisplayName(payload.skillId)
            playCombatResultEffects(player, result)
            local levelUpSummary = collectLevelUpSummary(result)
            if levelUpSummary.didAnyLevelUp then
                celebrateLevelUp(player, levelUpSummary)
            else
                local hitCount = #(result.hits or {})
                local totalDamage = 0
                for _, hit in ipairs(result.hits or {}) do
                    totalDamage += hit.damage or hit.totalDamage or 0
                end
                showMessage(player, string.format('%s hit %d target(s) for %d total damage.', skillName, hitCount, totalDamage))
            end
        elseif not ok then
            showMessage(player, 'Skill failed: ' .. tostring(result))
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.UseInstantSkill then
        local ok, result = CombatService.useInstantSkill(player, payload.skillId)
        if ok and type(result) == 'table' then
            playSkillEffect(player, result.effect)
            showMessage(player, result.message or (getSkillDisplayName(payload.skillId) .. ' used.'))
        elseif not ok then
            showMessage(player, 'Skill failed: ' .. tostring(result))
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.ParryAction then
        local ok, reason = CombatService.startParryWindow(player)
        if ok then
            broadcastParryResult(player, {
                result = 'window_opened',
                cooldownSeconds = 4.0,
                windowSeconds = 0.5,
            })
        else
            showMessage(player, 'Parry failed: ' .. tostring(reason))
        end
    elseif action == GameplayNetDefs.Actions.SetHotbarSkill then
        local ok, reason = PlayerDataService.setHotbarSkill(player, payload.slotIndex, payload.skillId)
        if not ok then
            showMessage(player, 'Hotbar update failed: ' .. tostring(reason))
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.SetHotbarItem then
        local ok, reason = PlayerDataService.setHotbarItem(player, payload.slotIndex, payload.itemId)
        if not ok then
            showMessage(player, 'Bag shortcut failed: ' .. tostring(reason))
        elseif payload.itemId and payload.itemId ~= '' then
            local itemDef = ItemDefs[payload.itemId]
            showMessage(player, string.format('%s placed on hotbar slot %s.', itemDef and itemDef.name or tostring(payload.itemId), tostring(payload.slotIndex)))
        else
            showMessage(player, string.format('Cleared hotbar slot %s.', tostring(payload.slotIndex)))
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.SetCustomSkillHotkey then
        local ok, reason = PlayerDataService.setCustomSkillHotkey(player, payload.keyCodeName, payload.skillId)
        if not ok then
            showMessage(player, 'Hotkey update failed: ' .. tostring(reason))
        elseif payload.skillId and payload.skillId ~= '' then
            showMessage(player, string.format('%s bound to %s.', tostring(payload.skillId), tostring(payload.keyCodeName)))
        else
            showMessage(player, string.format('Removed hotkey %s.', tostring(payload.keyCodeName)))
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.BuyShopItem then
        local itemId = payload.itemId
        local amount = math.max(math.floor(tonumber(payload.amount) or 1), 1)
        local itemDef = itemId and ItemDefs[itemId] or nil
        if not itemDef or not itemDef.buyPrice or itemDef.buyPrice <= 0 then
            showMessage(player, 'That item is not sold here.')
        else
            local totalCost = itemDef.buyPrice * amount
            local ok, reason = pcall(function()
                InventoryService.spendZeny(player, totalCost)
                InventoryService.grantItem(player, itemId, amount)
            end)
            if ok then
                showMessage(player, string.format('Bought %dx %s.', amount, itemDef.name))
            else
                showMessage(player, 'Purchase failed: ' .. tostring(reason))
            end
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.SellInventoryItem then
        local itemId = payload.itemId
        local amount = math.max(math.floor(tonumber(payload.amount) or 1), 1)
        local itemDef = itemId and ItemDefs[itemId] or nil
        if not itemDef or (itemDef.sellPrice or 0) <= 0 then
            showMessage(player, 'That item cannot be sold.')
        elseif not InventoryService.removeInventoryAmount(player, itemId, amount) then
            showMessage(player, 'Not enough items to sell.')
        else
            InventoryService.addZeny(player, (itemDef.sellPrice or 0) * amount)
            showMessage(player, string.format('Sold %dx %s.', amount, itemDef.name))
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.EquipItemInstance then
        local itemInstance = InventoryService.getEnhanceableItem(player, payload.itemInstanceId)
        if itemInstance and itemInstance.slot then
            PlayerDataService.getOrCreateProfile(player).equipment[itemInstance.slot] = itemInstance.instanceId
            showMessage(player, string.format('Equipped %s.', itemInstance.itemId))
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.UnequipItemInstance then
        local ok, reason = InventoryService.unequipItemInstance(player, tostring(payload.itemInstanceId or ''))
        if ok then
            showMessage(player, 'Unequipped item.')
        else
            showMessage(player, 'Unequip failed: ' .. tostring(reason))
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.SocketCardIntoEquipment then
        local ok, reason = InventoryService.socketCardIntoEquipment(player, tostring(payload.itemInstanceId or ''), tostring(payload.cardId or ''))
        if ok then
            local itemInstance = InventoryService.getEnhanceableItem(player, tostring(payload.itemInstanceId or ''))
            local cardDef = CardDefs[tostring(payload.cardId or '')]
            showMessage(
                player,
                {
                    text = string.format(
                        'Socketed %s into %s.',
                        cardDef and cardDef.name or tostring(payload.cardId),
                        itemInstance and ItemDefs[itemInstance.itemId] and ItemDefs[itemInstance.itemId].name or 'armor'
                    ),
                    soundCue = 'upgrade_success',
                }
            )
        elseif reason == 'CardSlotsFull' then
            showMessage(player, 'That gear has no open card slots left.')
        elseif reason == 'UnsupportedEquipmentSlot' then
            showMessage(player, 'That card cannot be slotted into this gear.')
        elseif reason == 'NoCardSlots' then
            showMessage(player, 'That gear has no card slots.')
        elseif reason == 'CardNotOwned' then
            showMessage(player, 'You do not own that card anymore.')
        else
            showMessage(player, 'Socket failed: ' .. tostring(reason))
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.UseInventoryItem then
        local ok, reason = useInventoryItem(player, tostring(payload.itemId or ''))
        showMessage(player, reason)
        pushState(player)
    elseif action == GameplayNetDefs.Actions.WarpToTown then
        local ok, reason = warpPlayerToTown(player)
        if not ok then
            showMessage(player, 'Town warp failed: ' .. tostring(reason))
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.WarpToField then
        local ok, reason = DungeonService.warpPlayerToField(player)
        if not ok then
            showMessage(player, 'Field warp failed: ' .. tostring(reason))
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.WarpToDungeon then
        local ok, reason = DungeonService.warpPlayerToDungeon(player, payload.dungeonId or 'ant_hell_floor_1')
        if not ok then
            showMessage(player, 'Warp failed: ' .. tostring(reason))
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.HealPlayer then
        healPlayer(player)
        showMessage(player, 'Fully healed.')
        pushState(player)
    elseif action == GameplayNetDefs.Actions.PreviewEnhancement then
        handleBlacksmithPreview(player)
    elseif action == GameplayNetDefs.Actions.RequestEnhancement then
        local result = EnhancementSystem.tryEnhance(player, {
            itemInstanceId = payload.itemInstanceId,
            protectionItemId = payload.protectionItemId,
        }, {
            inventoryGateway = InventoryService,
            statsGateway = StatService,
        })
        events.StateUpdated:FireClient(player, getGameState(player))
        if result.success then
            showMessage(player, {
                text = string.format('Enhancement result: %s -> %s', tostring(result.previousLevel or '?'), tostring(result.newLevel or '?')),
                soundCue = 'upgrade_success',
            })
        else
            showMessage(player, string.format('Enhancement result: %s -> %s', tostring(result.previousLevel or '?'), tostring(result.newLevel or '?')))
        end
    elseif action == GameplayNetDefs.Actions.AttemptAdvanceClass then
        local ok, reason, nextClassId = PlayerDataService.advanceClass(player)
        showMessage(player, ok and ('Advanced to ' .. tostring(nextClassId)) or ('Advance failed: ' .. tostring(reason)))
        pushState(player)
    elseif action == GameplayNetDefs.Actions.AttemptRebirth then
        local ok, reason = PlayerDataService.rebirth(player)
        showMessage(player, ok and 'Rebirth complete.' or ('Rebirth failed: ' .. tostring(reason)))
        pushState(player)
    elseif action == GameplayNetDefs.Actions.ChangeArchetype then
        local ok, reason = PlayerDataService.changeArchetype(player, payload.archetypeId)
        local archetypeDef = ArchetypeDefs[payload.archetypeId or '']
        local successMessage = string.format('Switched to %s. Each path now keeps its own progression.', archetypeDef and archetypeDef.displayName or 'that path')
        showMessage(player, ok and successMessage or ('Job change failed: ' .. tostring(reason)))
        pushState(player)
    elseif action == GameplayNetDefs.Actions.InviteNearestPlayerToParty then
        local ok, result = PartyService.inviteNearestPlayer(player)
        showMessage(player, ok and ('Invited ' .. tostring(result) .. ' into the party.') or ('Party invite failed: ' .. tostring(result)))
        pushState(player)
        if ok then
            for _, member in ipairs(PartyService.getPartyMembers(player)) do
                pushState(member)
            end
        end
    elseif action == GameplayNetDefs.Actions.LeaveParty then
        local currentMembers = PartyService.getPartyMembers(player)
        local ok, reason = PartyService.leaveParty(player)
        showMessage(player, ok and 'You left the party.' or ('Leave party failed: ' .. tostring(reason)))
        pushState(player)
        if ok then
            for _, member in ipairs(currentMembers) do
                if member ~= player then
                    pushState(member)
                end
            end
        end
    elseif action == GameplayNetDefs.Actions.SendChatMessage then
        local handledCommand, shouldPushState = handleChatCommand(player, payload.channel, payload.text)
        if handledCommand then
            if shouldPushState then
                pushState(player)
            end
            return
        end

        local ok, reason, recipients, chatPayload = ChatService.sendMessage(player, payload.channel, payload.text)
        if not ok then
            showMessage(player, 'Chat failed: ' .. tostring(reason))
        elseif recipients and chatPayload then
            sendChatPayload(recipients, chatPayload)
        end
    elseif action == GameplayNetDefs.Actions.OpenStorePlaceholder then
        events.OpenStorePlaceholder:FireClient(player, {
            title = 'Cash Shop Placeholder',
            message = 'Cosmetic pulls, passes, and subscription hooks will live here.',
        })
    elseif action == GameplayNetDefs.Actions.AdminSetBaseStatValue then
        if not isAdmin then
            showMessage(player, 'Admin access denied.')
            return
        end
        local ok, reason = PlayerDataService.setBaseStatValue(player, payload.statName, payload.value or 1)
        showMessage(player, ok and ('Set ' .. tostring(payload.statName) .. ' to ' .. tostring(payload.value) .. '.') or ('Admin stat update failed: ' .. tostring(reason)))
        pushState(player)
    elseif action == GameplayNetDefs.Actions.AdminMaxAllBaseStats then
        if not isAdmin then
            showMessage(player, 'Admin access denied.')
            return
        end
        PlayerDataService.maxAllBaseStats(player)
        showMessage(player, 'All base stats set to max.')
        pushState(player)
    elseif action == GameplayNetDefs.Actions.AdminResetBaseStats then
        if not isAdmin then
            showMessage(player, 'Admin access denied.')
            return
        end
        PlayerDataService.resetBaseStats(player)
        showMessage(player, 'Base stats reset to defaults.')
        pushState(player)
    elseif action == GameplayNetDefs.Actions.AdminGrantBaseLevels then
        if not isAdmin then
            showMessage(player, 'Admin access denied.')
            return
        end
        local amount = tonumber(payload.amount) or 1
        local ok, reason, levelUpSummary = PlayerDataService.grantBaseLevels(player, amount)
        if ok then
            celebrateLevelUp(player, levelUpSummary)
        else
            showMessage(player, 'Admin base level update failed: ' .. tostring(reason))
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.AdminGrantJobLevels then
        if not isAdmin then
            showMessage(player, 'Admin access denied.')
            return
        end
        local amount = tonumber(payload.amount) or 1
        local ok, reason, levelUpSummary = PlayerDataService.grantJobLevels(player, amount)
        if ok then
            celebrateLevelUp(player, levelUpSummary)
        else
            showMessage(player, 'Admin job level update failed: ' .. tostring(reason))
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.AdminSetSkillRank then
        if not isAdmin then
            showMessage(player, 'Admin access denied.')
            return
        end
        local ok, reason = PlayerDataService.setSkillRank(player, payload.skillId, payload.rank or 0)
        showMessage(player, ok and ('Set ' .. tostring(payload.skillId) .. ' to Lv ' .. tostring(payload.rank) .. '.') or ('Admin skill update failed: ' .. tostring(reason)))
        pushState(player)
    elseif action == GameplayNetDefs.Actions.AdminMaxAllSkills then
        if not isAdmin then
            showMessage(player, 'Admin access denied.')
            return
        end
        PlayerDataService.maxAllAvailableSkills(player)
        showMessage(player, 'All visible skills set to max rank.')
        pushState(player)
    elseif action == GameplayNetDefs.Actions.AdminResetSkillOverrides then
        if not isAdmin then
            showMessage(player, 'Admin access denied.')
            return
        end
        PlayerDataService.resetSkillOverrides(player)
        showMessage(player, 'Skill overrides reset to natural progression.')
        pushState(player)
    elseif action == GameplayNetDefs.Actions.AdminSetNoCooldowns then
        if not isAdmin then
            showMessage(player, 'Admin access denied.')
            return
        end
        local enabled = payload.enabled == true
        PlayerDataService.setAdminNoCooldowns(player, enabled)
        local effectiveEnabled = PlayerDataService.getOrCreateProfile(player).settings.adminNoCooldowns == true
        if PlayerDataService.isAdminPowerEnabled(player) then
            showMessage(player, 'Admin mode keeps No Cooldowns enabled.')
        else
            showMessage(player, if effectiveEnabled then 'No Cooldowns enabled.' else 'No Cooldowns disabled.')
        end
        pushState(player)
    elseif action == GameplayNetDefs.Actions.ParryAction then
        local ok, reason = CombatService.startParryWindow(player)
        if not ok then
            -- Silently ignore cooldown hits — client handles UI
            return
        end
        -- Send confirmation back to client for HUD
        events.ParryResult:FireClient(player, {
            result = 'window_opened',
            cooldownSeconds = 4,
        })
    end
end

local function handleAction(player, payload)
    local ok, err = pcall(handleActionImpl, player, payload)
    if not ok then
        warn(string.format('SliceRuntimeService.handleAction failed for %s: %s', player.Name, tostring(err)))
        showMessage(player, 'Action failed on server. Check Output for details.')
    end
end

local function wirePrompt(prompt, callback)
    if not prompt then
        warn('SliceRuntimeService: missing prompt during wirePrompt.')
        return
    end

    prompt.Triggered:Connect(function(player)
        callback(player)
        pushState(player)
    end)
end

local function wireClickDetector(clickDetector, callback)
    if not clickDetector then
        warn('SliceRuntimeService: missing click detector during wireClickDetector.')
        return
    end

    clickDetector.MouseClick:Connect(function(player)
        callback(player)
        pushState(player)
    end)
end

local function wireInteraction(prompt, clickDetector, callback)
    wirePrompt(prompt, callback)
    wireClickDetector(clickDetector, callback)
end

local function movePlayerToTown(player)
    task.spawn(function()
        local character = player.Character or player.CharacterAdded:Wait()
        local rootPart = character and character:WaitForChild('HumanoidRootPart', 5)
        if rootPart then
            task.wait(0.2)
            rootPart.CFrame = WorldService.getTownSpawnCFrame()
        end
    end)
end

function SliceRuntimeService.init()
    local foundFolder = nil
    for _, child in ipairs(ReplicatedStorage:GetChildren()) do
        if child.Name == 'Remotes' then
            if child:IsA('Folder') then
                if not foundFolder then
                    foundFolder = child
                else
                    child:Destroy()
                end
            else
                child:Destroy()
            end
        end
    end

    remotesFolder = foundFolder or Instance.new('Folder')
    remotesFolder.Name = 'Remotes'
    remotesFolder.Parent = ReplicatedStorage

    for _, name in pairs(GameplayNetDefs.RemoteEvents) do
        events[name] = ensureRemoteEvent(name)
    end
    local bossWindUpRemote  = ensureRemoteEvent(GameplayNetDefs.RemoteEvents.BossWindUp)
    local parryResultRemote = ensureRemoteEvent(GameplayNetDefs.RemoteEvents.ParryResult)
    events.BossWindUp  = bossWindUpRemote
    events.ParryResult = parryResultRemote
    for _, name in pairs(GameplayNetDefs.RemoteFunctions) do
        functionsMap[name] = ensureRemoteFunction(name)
    end
end

function SliceRuntimeService.start()
    functionsMap.GetGameState.OnServerInvoke = function(player)
        return getGameState(player)
    end

    events.RequestAction.OnServerEvent:Connect(handleAction)

    local worldRefs = WorldService.getWorldRefs()
    wireInteraction(worldRefs.healerPrompt, worldRefs.healerClickDetector, function(player)
        healPlayer(player)
        showMessage(player, 'All HP, mana, and ailments restored.')
    end)
    wireInteraction(worldRefs.warperPrompt, worldRefs.warperClickDetector, function(player)
        events.OpenWarpMenu:FireClient(player, getGameState(player).dungeons)
    end)
    wireInteraction(worldRefs.fieldGatePrompt, worldRefs.fieldGateClickDetector, function(player)
        local _ = DungeonService.warpPlayerToField(player)
    end)
    wireInteraction(worldRefs.entrancePrompt, worldRefs.entranceClickDetector, function(player)
        local _ = DungeonService.warpPlayerToDungeon(player, 'ant_hell_floor_1')
    end)
    wireInteraction(worldRefs.niffheimGatePrompt, worldRefs.niffheimGateClickDetector, function(player)
        local _ = DungeonService.warpPlayerToNiffheim(player)
    end)
    wireInteraction(worldRefs.niffheimReturnPrompt, worldRefs.niffheimReturnClickDetector, function(player)
        local _ = warpPlayerToTown(player)
    end)
    wireInteraction(worldRefs.blacksmithPrompt, worldRefs.blacksmithClickDetector, handleBlacksmithPreview)
    wireInteraction(worldRefs.rebirthPrompt, worldRefs.rebirthClickDetector, function(player)
        events.OpenRebirthMenu:FireClient(player, getGameState(player))
    end)
    wireInteraction(worldRefs.jobChangerPrompt, worldRefs.jobChangerClickDetector, function(player)
        events.OpenJobChangeMenu:FireClient(player)
    end)
    wireInteraction(worldRefs.shopPrompt, worldRefs.shopClickDetector, function(player)
        events.OpenShopMenu:FireClient(player, buildShopPayload('prontera_general_shop'))
    end)
    wireInteraction(worldRefs.storePrompt, worldRefs.storeClickDetector, function(player)
        events.OpenStorePlaceholder:FireClient(player, {
            title = 'Monetization Hook Placeholder',
            message = 'Launch offers, cosmetic gacha, passes, and subscription entry live here.',
        })
    end)

    Players.PlayerAdded:Connect(function(player)
        player.Chatted:Connect(function(msg)
            handleChatCommand(player, 'Local', msg)
        end)
        player.CharacterAdded:Connect(function(character)
            local rootPart = character:WaitForChild('HumanoidRootPart', 5)
            local humanoid = character:WaitForChild('Humanoid', 5)
            if rootPart then
                movePlayerToTown(player)
            end
            if humanoid then
                updateCharacterStats(player)
                humanoid.Died:Connect(function()
                    local lostExperience = PlayerDataService.applyDeathPenalty(player)
                    showMessage(player, string.format('You died and lost %d base EXP.', lostExperience))
                    pushState(player)
                end)
            end
            pushState(player)
        end)
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        player.Chatted:Connect(function(msg)
            handleChatCommand(player, 'Local', msg)
        end)
        player.CharacterAdded:Connect(function(character)
            local rootPart = character:WaitForChild('HumanoidRootPart', 5)
            local humanoid = character:WaitForChild('Humanoid', 5)
            if rootPart then
                movePlayerToTown(player)
            end
            if humanoid then
                updateCharacterStats(player)
                humanoid.Died:Connect(function()
                    local lostExperience = PlayerDataService.applyDeathPenalty(player)
                    showMessage(player, string.format('You died and lost %d base EXP.', lostExperience))
                    pushState(player)
                end)
            end
            pushState(player)
        end)

        if player.Character then
            movePlayerToTown(player)
            updateCharacterStats(player)
            pushState(player)
        end
    end

    task.spawn(function()
        while true do
            task.wait(4)
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character and player.Character.Parent then
                    updateCharacterStats(player)
                    applyNaturalRegen(player)
                    pushState(player)
                end
            end
        end
    end)
end

function SliceRuntimeService.pushState(player)
    pushState(player)
end

function SliceRuntimeService.showMessage(player, text: string)
    showMessage(player, text)
end

function SliceRuntimeService.sendSystemChat(player, text: string, channel: string?)
    sendSystemChat(player, channel, text)
end

function SliceRuntimeService.broadcastSystemChat(text: string, channel: string?)
    broadcastSystemChat(channel, text)
end

function SliceRuntimeService.broadcastBossWindUp(payload)
    if events.BossWindUp then
        for _, p in ipairs(Players:GetPlayers()) do
            events.BossWindUp:FireClient(p, payload)
        end
    end
end

function SliceRuntimeService.broadcastParryResult(player: Player, payload)
    if events.ParryResult then
        events.ParryResult:FireClient(player, payload)
    end
end

function SliceRuntimeService.broadcastBossWindUp(payload)
    broadcastBossWindUp(payload)
end

function SliceRuntimeService.broadcastParryResult(player, payload)
    broadcastParryResult(player, payload)
end

return SliceRuntimeService
