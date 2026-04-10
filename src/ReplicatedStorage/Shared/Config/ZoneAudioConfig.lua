--!strict

local ZoneAudioConfig = {
    fallbackZoneId = 'town',
    zoneTracks = {
        town = {
            name = 'Prontera',
            soundId = 'rbxassetid://72687045215463',
            volume = 0.42,
            center = Vector3.new(0, 0, 0),
            size = Vector2.new(210, 210),
        },
        prontera_field = {
            name = 'prontera field',
            soundId = 'rbxassetid://70586997300545',
            volume = 0.4,
            center = Vector3.new(248, 0, -20),
            size = Vector2.new(240, 170),
        },
        ant_hell_floor_1 = {
            name = 'Anthell',
            soundId = 'rbxassetid://73580855470991',
            volume = 0.44,
            center = Vector3.new(0, 0, 238),
            size = Vector2.new(150, 150),
        },
        niffheim = {
            name = 'Niffheim',
            soundId = 'rbxassetid://117645121650587',
            volume = 0.48,
            center = Vector3.new(1680, 0, 1280),
            size = Vector2.new(560, 460),
        },
        tower_of_ascension = {
            name = 'Tower_of_Ascension',
            soundId = '',
            volume = 0,
            center = Vector3.new(-172, 0, -96),
            size = Vector2.new(120, 120),
        },
    },
    zoneOrder = {
        'prontera_field',
        'ant_hell_floor_1',
        'niffheim',
        'tower_of_ascension',
    },
}

return ZoneAudioConfig
