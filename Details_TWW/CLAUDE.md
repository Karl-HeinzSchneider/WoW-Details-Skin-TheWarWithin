# Details_TWW (the addon)

The distributable addon: everything in this folder ships; the packager copies it to the top of the
zip (`.pkgmeta`). User settings live in `Details_TWWDB` (AceDB).

## Load order (`Details_TWW.toc`)

The TOC is the manifest and the source of truth for the load order; **every new Lua/XML file must
be listed**. The order follows these rules:

1. `embeds.xml` first: every vendored library in dependency order (LibStub → CallbackHandler →
   Ace\* → LibSharedMedia → LibDataBroker → LibDBIcon).
2. `src\core\`: `logger.lua` first (everything logs), `db.lua` (the defaults `ace.lua` needs),
   `ace.lua` (creates `app.addon`), then the Ace modules that hang off it (`options.lua`,
   `minimapbutton.lua`).
3. Feature code after the core: `src\<feature>\*.lua`, or `modules\<name>\` with a loader XML
   per module listed in a `modules\modules.xml`. In UI code, each Lua mixin comes before the XML
   that names it.
4. `Details_TWW.lua` last; it only logs.

## Files

### `src/core/`

- `logger.lua` — `app.logger`: leveled, colored chat logging; `log("x")` is `log:info("x")`,
  `log:debug("Looted %s x%d", link, count)` formats, `log:chat(...)` is unfiltered user-facing
  output, `log:dump(tbl)` prints a table at DEBUG. The threshold comes from `profile.logLevel`.
- `db.lua` — `app.dbDefaults` for AceDB: `profile` = user settings (`logLevel`, `minimap`;
  `minimapPos` = 200° so an undragged button doesn't sit on LibDBIcon's shared 225° default),
  `char` = per-character data, `global.dbVersion` for future migrations.
- `ace.lua` — `app.addon`, the AceAddon object (AceConsole, AceEvent). `OnInitialize` opens
  `app.db`, wires the profile callbacks to `OnProfileRefresh` (log level, then every module's
  `OnProfileRefresh`) and registers `/details_tww` and `/tww`; `OnSlashCommand` handles `options` (the
  default), `loglevel <level>` and `reset`. Register game events in `OnEnable`.
- `options.lua` — `app.options`: the user options as **one** AceConfig table (plus the AceDBOptions
  profiles tab), registered in the game's Settings panel (`AddToBlizOptions`) and opened in a
  standalone AceConfigDialog window by `Open()`. A new option goes only here. `Refresh()` redraws
  them after a setting changed elsewhere.
- `minimapbutton.lua` — `app.minimapButton`, a LibDataBroker launcher + LibDBIcon that opens the
  options and honors `profile.minimap`. Optional: to drop it, delete the file, its TOC line, the
  `minimap` option and `profile.minimap`.

### `src/blizzard/`

- `damagemeter.lua` — `app.blizzardDamageMeter`: the skin for Blizzard's built-in damage meter.
  It hooks `DamageMeterEntryMixin.UpdateStyle`/`UpdateIcon`/`SetBarHeight` and `DamageMeter:SetupSessionWindow`
  once `Blizzard_DamageMeter` is loaded, and swaps the header, the bars (cast bar look) and player
  class icons (row-high), and gives the bar texts Friz Quadrata (`GameFontHighlight`). `profile.blizzardDamageMeter.enabled` turns it on and off (restoring Blizzard's
  atlases), `barFill` picks the fill texture; `Apply()` re-skins everything that exists. See the root `CLAUDE.md` for the approach.

### `src/details/`

- `skin.lua` — `app.detailsSkin`: the Details! skin. `OnInitialize` registers our LibSharedMedia
  statusbar media (and the legacy names), installs the cached "The War Within" skin and an identical
  "The War Within (no cache)" variant with `Details:InstallSkin` and hooks
  `Details.RefreshTitleBar` to 3-slice our header, `Details.ChangeSkin` to hide the window texture's
  own header band, and `Details.InstanceRefreshRows`/
  `Details.gump.CreateNewLine` to anchor our row background to the bar instead of the whole row, and
  `Details.SetClassIcon` to draw our class icon where Details! can't map Blizzard's spec icon id
  (every player on WoW Forever). It never changes a window on its own;
  Both variants use the same hooks. `ApplyToAllWindows()` (the options button) switches every open
  window to the cached variant. `IsAvailable()` is false
  without Details!. See the root `CLAUDE.md` for the API notes.
  After registering media and hooks, existing windows using our header refresh their title bar:
  cached windows can have loaded a fallback texture before our media names were available.

### Annotations (not in the TOC)

- `src/types.lua` — the private-table class `Details_TWW` (`app.*` fields) and
  `Details_TWW.DB`. When a file adds a member to `app`, add a matching `---@field` here.

### Other

- `lib/` — vendored Ace3, LibStub, CallbackHandler, LibSharedMedia-3.0 (copied from Details!), LibDBIcon (+ LibDataBroker). Excluded from
  LuaLS, StyLua and Prettier; update by replacing the folder, don't patch. `embeds.xml` loads all
  of them; drop a line there (not the folder) to skip a library the addon doesn't use.
- `assets/` — textures the game files cannot provide (`assets/core/coffee.tga` is the TOC notes'
  donation icon). `assets/skin/` holds the skin's art: `header` (256×32 `.blp`) and
  `ClassIconsTWW` (512×512, 64px class cells) from `legacy/Textures/`, and `bar_fill.tga` (512×32,
  Blizzard's `ui-castingbar-full-channel` cut out of `Interface\CastingBar\UICastingBar2x` and
  turned grey by luminance (Rec. 601) so the class color tints it; `bar_fill_bright.tga` is the same
  turned grey by the brightest channel, for `profile.blizzardDamageMeter.barFill = "bright"`).
  For Details!: `details_bar_fill`, `details_bar_fill_bright`, `details_bar_background`,
  `details_bar_border` (512×64 row textures, cast bar in the bottom 15 of 32px) and `specs.blp`
  (spec icons in Details!' layout, from `legacy/Textures/`). The bar background and border are not
  shipped; they come straight from `UICastingBar2x` by texture coordinates.

## Conventions

- Prototype-style Ace modules: define methods on a local `module` table and pass it to
  `addon:NewModule("Name", module, …)`; state lives on the object Ace returns (see
  `minimapbutton.lua`). A module that depends on profile settings defines `OnProfileRefresh`.
- New user settings get a default in `db.lua` and an entry in `options.lua`.
