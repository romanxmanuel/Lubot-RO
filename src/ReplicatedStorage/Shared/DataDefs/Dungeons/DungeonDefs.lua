--!strict

local DungeonDefs = {
    ant_hell_floor_1 = {
        id = 'ant_hell_floor_1',
        name = 'Anthell',
        recommendedLevel = 15,
        maxPartySize = 4,
        roomSequence = { 'entry', 'chamber_1', 'chamber_2' },
    },
    sewer_training_grounds = {
        id = 'sewer_training_grounds',
        name = 'Legacy Sewer Test',
        recommendedLevel = 3,
        maxPartySize = 4,
        roomSequence = { 'entry', 'wave_1', 'boss' },
    },
    tower_of_ascension = {
        id = 'tower_of_ascension',
        name = 'Tower_of_Ascension',
        recommendedLevel = 17,
        maxPartySize = 4,
        roomSequence = { 'arrival' },
    },
    niffheim = {
        id = 'niffheim',
        name = 'Niffheim',
        recommendedLevel = 40,
        maxPartySize = 4,
        roomSequence = { 'entry_bridge', 'dead_town', 'graveyard_hill', 'river_crossing', 'manor_edge' },
    },
}

return DungeonDefs
