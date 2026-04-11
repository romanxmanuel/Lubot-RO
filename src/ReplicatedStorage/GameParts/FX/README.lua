return [[
FX asset home. Put reusable particles, trails, hit flashes, dash visuals, and spell effect assets here.

Runtime note:
- MarketplaceVfxService keeps per-asset source folders at startup:
  - `MarketplaceAsset_7564537285`
  - `MarketplaceAsset_121170725728238` (Power Slash override)
  - `MarketplaceAsset_139055633559547` (Beam/Nova Strike override)
- MarketplaceVfxService also builds runtime templates in `MarketplaceVfx7564537285`.
- If InsertService cannot load an asset at runtime, MarketplaceVfxService falls back to any cached source content already present in the matching `MarketplaceAsset_<id>` folder.
- Client EffectsController reads runtime templates for PowerSlash/ArcFlare/NovaStrike/VortexSpin/CometDrop/RazorOrbit.
]]
