--!strict

local function cf(
    x: number,
    y: number,
    z: number,
    r00: number,
    r01: number,
    r02: number,
    r10: number,
    r11: number,
    r12: number,
    r20: number,
    r21: number,
    r22: number
): CFrame
    return CFrame.new(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end

return {
    zoltraak = {
        id = 'zoltraak',
        displayName = 'Zoltraak',
        aliases = { 'zoltraak', 'zol', 'zt', 'town', 'home' },
        spawnCFrame = CFrame.lookAt(
            Vector3.new(-301.8163, 8.7500, 285.0104),
            Vector3.new(-304.0001, 8.7500, 226.9353)
        ),
    },
    prontera_field = {
        id = 'prontera_field',
        displayName = 'Prontera Field',
        aliases = { 'pronterafield', 'field', 'field1', 'pf', 'prontera', 'pron' },
        spawnCFrame = cf(552, 2.06, -20, 0, -0.0440481156, -0.999029398, 0, 0.999029398, -0.0440481156, 1, 0, 0),
    },
    ant_hell = {
        id = 'ant_hell',
        displayName = 'Ant Hell',
        aliases = { 'anthell', 'ant', 'ants', 'ah' },
        spawnCFrame = cf(-56, 2, 196, -0.600000024, -0.0228478201, -0.799673676, 0, 0.999592185, -0.0285597742, 0.800000012, -0.017135866, -0.599755287),
    },
    ice_moon = {
        id = 'ice_moon',
        displayName = 'IceMoon',
        aliases = { 'icemoon', 'ice', 'moon', 'im' },
        spawnCFrame = cf(-838, 10, 781, 0, 0.0344622731, -0.99940604, 0, 0.99940598, 0.0344622768, 0.99999994, 0, 0),
    },
    lubidrium = {
        id = 'lubidrium',
        displayName = 'Lubidrium',
        aliases = { 'lubidrium', 'lubi', 'lubu', 'lab' },
        spawnCFrame = CFrame.new(-1877.7672, 886.9773, 57.0324),
    },
    abyss_sanctuary = {
        id = 'abyss_sanctuary',
        displayName = 'Abyss Sanctuary',
        aliases = { 'abyss', 'abysssanctuary', 'sanctuary', 'as' },
        spawnCFrame = cf(0, 8, 769, 0, 0, -1, 0, 1, 0, 1, 0, 0),
    },
    niffheim = {
        id = 'niffheim',
        displayName = 'Niffheim',
        aliases = { 'niffheim', 'niff', 'nh' },
        spawnCFrame = cf(1438, 8.2, 1260, -0.0889319479, 0.000885794405, -0.996037245, 0, 0.999999523, 0.000889318122, 0.996037722, 7.90887934e-05, -0.0889319032),
    },
    tower_of_ascension = {
        id = 'tower_of_ascension',
        displayName = 'Tower Of Ascension',
        aliases = { 'tower', 'toa', 'towerofascension', 'ascension' },
        spawnCFrame = cf(-172, 101, -96, 0.72679168, 0, 0.686858058, 0, 1.00000012, 0, -0.686858058, 0, 0.72679168),
    },
    bloody_church = {
        id = 'bloody_church',
        displayName = 'Bloody Church',
        aliases = { 'bloodychurch', 'church3', 'bloody', 'bc' },
        spawnCFrame = CFrame.new(20000, 5, 185),
    },
    abandoned_church = {
        id = 'abandoned_church',
        displayName = 'Abandoned Church',
        aliases = { 'abandonedchurch', 'church1', 'ac' },
        spawnCFrame = CFrame.new(6000, 63, -30),
    },
    abandoned_gothic_church = {
        id = 'abandoned_gothic_church',
        displayName = 'Abandoned Gothic Church',
        aliases = { 'abandonedgothicchurch', 'church2', 'gothicchurch', 'agc' },
        spawnCFrame = CFrame.new(9000, 58, 0),
    },
    church_of_lost_souls = {
        id = 'church_of_lost_souls',
        displayName = 'Church Of Lost Souls',
        aliases = { 'churchoflostsouls', 'lostsouls', 'cols', 'soulschurch' },
        spawnCFrame = CFrame.new(16000, 6.25, -200),
    },
}
