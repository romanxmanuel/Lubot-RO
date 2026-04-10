--!strict

local ArchetypeDefs = {
    knight_path = {
        id = 'knight_path',
        family = 'Melee',
        displayName = 'Knight Line',
        stageSequence = {
            'knight',
            'high_knight',
            'knight_rebirthed',
            'lord_knight',
        },
        signatureFantasy = 'A front-line weapons master who turns heavy commitment into visible battlefield control and prestige.',
        statPreferences = {
            primary = { 'STR', 'VIT' },
            secondary = { 'DEX', 'AGI' },
            optional = { 'LUK' },
        },
        earlyGameFeel = 'Stable, direct, and satisfying. Big single-target hits, forgiving survivability, and easy understanding.',
        lateGamePayoff = 'Becomes an armored wrecking force with screen-filling cleaves, strong initiation, and obvious social presence.',
        visualEscalation = {
            early = 'Iron and leather beginner look with modest slash trails and grounded impact sparks.',
            mid = 'Heavier armor silhouette, brighter weapon trails, shield shockwaves, and stronger ground impact effects.',
            late = 'Commanding knight energy, crimson-gold cleave arcs, and boss-room-worthy entry effects.',
        },
    },
    assassin_path = {
        id = 'assassin_path',
        family = 'Ambush',
        displayName = 'Assassin Line',
        stageSequence = {
            'assassin',
            'high_assassin',
            'assassin_rebirthed',
            'assassin_cross',
        },
        signatureFantasy = 'A shadow predator who lives off attack speed, crit spikes, and sudden burst windows that make every opening feel lethal.',
        statPreferences = {
            primary = { 'AGI', 'LUK' },
            secondary = { 'DEX', 'STR' },
            optional = { 'VIT' },
        },
        earlyGameFeel = 'Quick, slippery, and hungry. You feel the crit fantasy early and basic attacks ramp into a fast, addictive tempo.',
        lateGamePayoff = 'Turns into an Assassin Cross who shreds targets through katar crit chains, Sonic Blow burst, and poison-fueled execution windows.',
        visualEscalation = {
            early = 'Dark leathers, short twin blades, and quick shadow streaks on movement and strikes.',
            mid = 'Sharper silhouette, richer crimson accents, faster slash afterimages, and stronger stealth aura beats.',
            late = 'Royal shadow prestige with poison glows, cross-slash burst trails, and unmistakable assassin-cross swagger.',
        },
    },
    archer_path = {
        id = 'archer_path',
        family = 'Ranged',
        displayName = 'Archer Line',
        stageSequence = {
            'archer',
            'high_archer',
            'archer_rebirthed',
            'sniper',
        },
        signatureFantasy = 'A precise and agile hunter who turns space, tempo, and crit moments into stylish damage spikes.',
        statPreferences = {
            primary = { 'DEX', 'AGI' },
            secondary = { 'LUK' },
            optional = { 'VIT' },
        },
        earlyGameFeel = 'Fast, readable, and rewarding. Clean shots, easy kiting, and immediate attack-speed satisfaction.',
        lateGamePayoff = 'Evolves into a high-precision crit machine with multi-shot bursts, trap control, and elegant boss shredding.',
        visualEscalation = {
            early = 'Simple arrow streaks, quickstep motion, and light wind accents.',
            mid = 'Multi-arrow fans, tracer shots, elevated stance confidence, and more visible crit flashes.',
            late = 'Storm volleys, luminous reticles, predator-mark effects, and iconic long-range burst spectacle.',
        },
    },
    mage_path = {
        id = 'mage_path',
        family = 'Caster',
        displayName = 'Mage Line',
        stageSequence = {
            'mage',
            'high_mage',
            'mage_rebirthed',
            'warlock',
        },
        signatureFantasy = 'A battlefield caster who controls space, amplifies party momentum, and escalates from simple spells into dramatic arcane dominance.',
        statPreferences = {
            primary = { 'INT' },
            secondary = { 'DEX', 'VIT' },
            optional = { 'LUK' },
        },
        earlyGameFeel = 'A little more deliberate, but rewarding once casts land. Strong spell identity and supportive utility.',
        lateGamePayoff = 'Turns into a flashy zone-control and burst caster with layered spell visuals, support windows, and clear raid value.',
        visualEscalation = {
            early = 'Runic circles, elemental bolts, and soft glow casting silhouettes.',
            mid = 'Larger sigils, chained spell impacts, aura-laced support casts, and stronger battlefield marking.',
            late = 'Cataclysmic arcane circles, multi-layered spell stacks, orbiting glyphs, and unmistakable caster prestige.',
        },
    },
    zero_path = {
        id = 'zero_path',
        family = 'Combo Hero',
        displayName = 'Zero Line',
        stageSequence = {
            'zero',
            'high_zero',
            'zero_rebirthed',
            'transcendent_zero',
        },
        signatureFantasy = 'A hyper-mobile combo hero who chains movement-heavy slashes, afterimages, and clone finishers into nonstop pressure.',
        statPreferences = {
            primary = { 'AGI', 'DEX' },
            secondary = { 'STR', 'LUK' },
            optional = { 'VIT' },
        },
        earlyGameFeel = 'Fast, fluid, and stylish. Every button moves you, and every hit wants to flow into the next.',
        lateGamePayoff = 'Turns into a stagger-window monster that dumps graceful burst strings faster than any other melee line.',
        visualEscalation = {
            early = 'Silver-blue slash trails, quickstep lunges, and clean sword echoes.',
            mid = 'Longer chain arcs, spectral follow-up silhouettes, and stronger landing bursts.',
            late = 'Royal time-split afterimages, clone cut-ins, and full-screen finisher energy during boss punish windows.',
        },
    },
    valkyrie_path = {
        id = 'valkyrie_path',
        family = 'Aerial',
        displayName = 'Valkyrie Line',
        stageSequence = {
            'valkyrie',
            'high_valkyrie',
            'valkyrie_rebirthed',
            'seraphim',
        },
        signatureFantasy = 'A divine winged warrior who commands the sky — the only class that fights in true 3D space, chaining aerial dashes, boost combos, and devastating dive attacks into a combat style no ground class can replicate.',
        statPreferences = {
            primary = { 'AGI', 'DEX' },
            secondary = { 'STR', 'INT' },
            optional = { 'LUK' },
        },
        earlyGameFeel = 'Liberating and vertical. The moment you take flight, the game opens up into a dimension no other class touches.',
        lateGamePayoff = 'Becomes a divine sky sovereign chaining boost combos into overdrive explosions, dive-bombing from altitude, and unleashing cinematic judgment attacks that reshape the battlefield.',
        visualEscalation = {
            early = 'Silver-white wing outlines, soft trailing light on limbs, gentle takeoff glow.',
            mid = 'Brighter wing silhouette, visible boost rings, wind beams during overdrive, ground impact sparks on dive.',
            late = 'Full radiant wings, divine golden-white energy, overdrive leaves permanent trail in the sky, judgment descent creates a crater of light.',
        },
    },
}

return ArchetypeDefs
