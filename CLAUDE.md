# CLAUDE.md

Guidance for Claude Code when working in this repository. This file holds the map and the rules
that apply everywhere; the addon folder has its own `CLAUDE.md` with its load order and file map.

## What this is

**Details_TWW** ("Details! Skin TWW") is a World of Warcraft addon that adds the **"The War
Within"** skin (inspired by /u/Sm0keO's mockup) to damage meters on every client:

1. **Blizzard's built-in damage meter** (`Blizzard_DamageMeter`): `src/blizzard/damagemeter.lua`.
2. **[Details!](https://www.curseforge.com/wow/addons/details)**, when it is installed:
   `src/details/skin.lua`. Without Details! that part does nothing.

It is Lua 5.1 on top of Ace3, and the repo also holds the Node/TypeScript tooling that checks, links
and packages it.

- Author: Karl-Heinz Schneider. CurseForge: <https://www.curseforge.com/wow/addons/details-skin-the-war-within>
  (project id `1083704`, set in the TOC as `## X-Curse-Project-ID`).
- `Details` is an optional dependency (`## OptionalDeps: Details`); the addon must work without it.
- The addon name and folder **must stay `Details_TWW`**. It is the folder name that existing
  CurseForge installs use, and texture paths are `Interface\AddOns\Details_TWW\...`.

### Status (2026-11-03): 2.0 rewrite from a fresh start

The repo was restructured on the WoW-AddonTemplate layout. `Details_TWW/` is the template's core
(logger, AceDB, options, minimap button, `/tww`) plus the Blizzard damage meter skin (header, cast bar
style bars, row-high class icons, Friz Quadrata bar text; toggled in the options) and a first Details!
skin (installed into Details!' skin list, untested in-game so far). The Evoker Augmentation bar is
left for later. The pre-2.0 addon is in [`legacy/`](legacy/) as reference
only (see "Legacy addon" below). Features are rebuilt piece by piece, usually from code references
the user provides.

### Blizzard damage meter: how it is skinned

`Blizzard_DamageMeter` is identical on Retail, Mists, Anniversary and Era. WoW Forever adds only
`Camelot/DamageMeterEntryOverrides.lua`, which hides classification icons. There is **no skin API**:
the styles are the fixed Edit Mode enum `Enum.DamageMeterStyle` (Default, Thin, Bordered,
FullBackground). So the module:

- waits for the addon with `EventUtil.ContinueOnAddOnLoaded("Blizzard_DamageMeter", ...)`;
- uses `hooksecurefunc` on `DamageMeterEntryMixin.UpdateStyle` (every bar, also the source window's
  spell bars), `DamageMeterEntryMixin.UpdateIcon` (every data refresh), `DamageMeterEntryMixin.SetBarHeight` (icon size) and
  `DamageMeter:SetupSessionWindow` (every window). XML mixins are copied into a frame when it is
  created, so frames that existed before the hook are hooked individually;
- only swaps art, and remembers Blizzard's atlases (in weak tables, never as fields on Blizzard
  frames) so turning the skin off restores them;
- never replaces Blizzard functions (the meter is an Edit Mode system, so taint matters) and never
  reads bar values (secret values in 12.x).

What it replaces:

| Blizzard                                                               | Ours                                                                                                                                                                                |
| ---------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| window `Header` (`ui-damagemeters-header-bar`, 32px)                   | own texture `header` over it, 3-sliced (20/100px) so the ornaments don't stretch; Blizzard's faded to alpha 0 (other regions anchor to it)                                          |
| bar fill `UI-HUD-CoolDownManager-Bar`                                  | `bar_fill.tga` (grey cast bar fill; `bar_fill_bright.tga` with the "Bright" option) via `SetStatusBarTexture`, vertex color carried over                                            |
| bar `Background` (per style atlas and insets)                          | cast bar background from `UICastingBar2x` by texcoords, re-anchored 1px outside the StatusBar                                                                                       |
| bar `BackgroundEdge` (`ui-damagemeters-bar-shadowedge`)                | cast bar border (`ui-castingbar-frame` region), already 2px outside the bar; shown also in the Bordered style                                                                       |
| player bar icon (spec icon / class atlas)                              | `ClassIconsTWW` cell of the class; spell bars and creatures keep Blizzard's icon; every bar's icon frame is a square as tall as the row (Blizzard: 24px), resized on `SetBarHeight` |
| bar `Name`/`Value` font (`NumberFontNormal`, outlined Arial Narrow 14) | `GameFontHighlight` (Friz Quadrata 12, shadow, white) via `SetFontObject`, so Blizzard's per-alphabet fallbacks stay; the Edit Mode text size still applies (`SetTextScale`)        |

The bars look like Blizzard's retail cast bar (as the legacy Details! skin did) in **every** Edit
Mode style; the style only decides the StatusBar's size and position, which stay Blizzard's (Thin
puts the name above the bar). The art is `Interface\CastingBar\UICastingBar2x` (1024x512), cut by the
retail atlas coordinates: the file is on every client (identical in the Classic art export), the
`ui-castingbar-*` atlases are not.

Lessons from in-game testing:

- **Atlases can carry texture slice margins, and `SetTexture` keeps them.** Reset them with
  `SetTextureSliceMargins(0, 0, 0, 0)` on every reused region (Blizzard's nameplates do the same), or
  use an own texture.
- **A StatusBar manages its fill's texture coordinates**, so `SetTexCoord` can't crop a fill; the
  fill needs its own file (`bar_fill.tga`), the other regions can use a sheet.
- **Blizzard's `UpdateBackground` resets the alpha of `Background` and `BackgroundEdge`**, so they are
  reused with our art instead of faded out.
- The legacy `bar.blp`/`background.blp` were made for Details!' 28px rows (an ~11px bar under the
  name) and look smeared on Blizzard's 24px bar; they are not used for the Blizzard meter.

Not touched yet: the window background
`MinimizeContainer.Background` (`damagemeters-background`), the header fonts (already Friz Quadrata 13 gold, `GameFontNormalMed1`, like the legacy title), the source window background and
spec icons (the legacy `specs.blp` sheet uses Details!' spec coordinates; Blizzard only gives a spec
icon file id).

### Details!: how it is skinned

Checked against Details! `#Details.20261015` (one package for every client). The API:

- `Details:InstallSkin(name, skin)` adds a skin to the skin list of Details!' options; it changes no
  window. `no_cache = true` lets it run any time and keeps Details! from storing a copy of the table
  in its saved variables (which would go stale and point at our files after we're gone). Windows
  whose skin is not installed yet wait for it and switch when it arrives.
- `instance:ChangeSkin(name)` applies it: after a config reset, `skin.instance_cprops` is copied over
  the window's settings **two levels deep** (a table under `row_info` replaces the window's whole
  table, so give every key; `row_info.texts` is the exception, Details! fills it from its defaults).
  A window already on the skin only refreshes, so `ApplyToAllWindows` clears `instance.skin` first.
- The skin's `callback` is no longer called; what settings can't do is a `hooksecurefunc` on a
  `Details` method (instances inherit from `Details` by metatable, so the hook reaches all windows).
- Details! starts its windows one frame after `PLAYER_LOGIN`, so installing in `OnInitialize` is early
  enough (`OptionalDeps: Details` loads it before us).
- Every texture a window uses (`row_info.texture`, `texture_background`, `overlay_texture`,
  `titlebar_texture`) is looked up through **LibSharedMedia by name**.

What our skin sets: the skin name is the legacy one (`|cff8080ffThe War Within|r`), so windows and
profiles saved with the old skin find it; the legacy media names are registered too. Rows are 32px:
a Details! bar always covers its whole row, so the row textures (`details_bar_*.tga`, 512x64 = a 32px
row at 2x, built from `UICastingBar2x` like the Blizzard bars) carry the cast bar in their bottom
15px and are transparent above it; `text_yoffset` 7 lifts the texts above the bar. Fill = grey cast
bar fill 2px inside, background 1px inside, border = the overlay texture (above the fill, not cut by
the value). Icons: `ClassIconsTWW`, spec icons `specs.blp` (Details!' spec layout). On Retail and WoW Forever
Details! reads Blizzard's damage meter (`Details:IsUsingBlizzardAPI`) and maps its `specIconID` to a
spec through DetailsFramework's table. On Forever `specIconID` is a secret value (`SecretValue` in its
`DamageMeterDocumentation.lua`; Retail's is `NeverSecret`), so the lookup fails and Details! draws
Blizzard's square icon. A hook on `Details.SetClassIcon` draws our class icon (from the never-secret
`classFilename`) whenever the icon is secret or unmapped. Title bar: 32px
`header`, 3-sliced by a hook on `Details.RefreshTitleBar`. Details! anchors a row's background to the
whole row (icon included) once at creation, so hooks on `Details.InstanceRefreshRows` and
`Details.gump.CreateNewLine` anchor it to the row's StatusBar while the window uses our background. Window frame art and anchors follow
Details!' "Minimalistic v2" (window background, the area behind the rows, at alpha 0); that frame texture also draws
a header band of its own (`cabecalho.ball`, `emenda`, `top_bg`, `ball_r`; in `/fstack` a dark strip at
the drag frame `DetailsUpFrameInstance<id>`), which a hook on `Details.ChangeSkin` hides for our skin
(hidden regions still work as anchors; only the ones we hid are shown again for another skin), and
`Install` does the same for windows skinned before the hook existed. Clearing their texture was not
enough: the band came back. The title text and menu offsets (`attribute_text.anchor`, `menu_anchor`)
are first guesses and need in-game tuning.

### Target clients

One TOC with a comma-separated `## Interface` line (numbers taken from the installed clients'
`.build.info` and matching Details!' own flavor TOCs):

| Client        | Version | Interface | Details! flavor TOC   |
| ------------- | ------- | --------- | --------------------- |
| Retail        | 12.1.5  | `120105`  | `Details.toc`         |
| Mists Classic | 5.5.4   | `50504`   | `Details_Mists.toc`   |
| Anniversary   | 2.5.6   | `20506`   | `Details_TBC.toc`     |
| Classic Era   | 1.15.9  | `11509`   | `Details_Classic.toc` |
| WoW Forever   | 1.60.1  | `16001`   | `Details_Camelot.toc` |

Code must work on every one of them. Branch on capabilities (`if C_Foo then`) rather than on
version numbers where possible. Where a real per-client split is needed, use `WOW_PROJECT_ID`. A
per-client TOC directive or a separate flavor TOC is also an option, but only after checking that
the clients support it (look at how Blizzard's own TOCs in the export do it).
When bumping, update all numbers in the TOC together.

| Part           | What it is                                                                                                                          | Details                                        |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| `Details_TWW/` | The addon: everything in it ships. Settings in `Details_TWWDB`.                                                                     | [Details_TWW/CLAUDE.md](Details_TWW/CLAUDE.md) |
| `src/`         | Root tooling (Node 20+, TypeScript run by `tsx`, no build): check the addons, link them into a client, package them. Never shipped. | see "Tooling" below                            |
| `.github/`     | The release workflows (BigWigs packager).                                                                                           | see "Releases" below                           |

A direct child directory with a same-named `.toc` is an addon; the tooling discovers addons that
way, so a second addon (e.g. an `Details_TWW_Options` companion) needs no registration in the
tooling — only a `move-folders` line in `.pkgmeta`. A companion named `Details_TWW_*` must
declare `## Dependencies: Details_TWW` (`npm run check:addons` enforces it).

## Working on the code

WoW addons are plain Lua/XML files loaded by the game; there is no build step. To try a change:
`npm run dev:link -- "<WoW>/Interface/AddOns"` (once; links every addon directory, also honors
`WOW_ADDONS_DIR`) and `/reload` in-game. Clients live under `D:\Spiele\World of Warcraft\`
(`_retail_`, `_classic_`, `_anniversary_`, `_classic_era_`, `_forever_`). `/tww` (or
`/details_tww`) opens the options, and `/tww loglevel debug` shows the debug log.

## Commands (Node 20+, run from the root after `npm install` once)

| Command                            | Does                                                                                                                                                                                                                                |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `npm run check`                    | Everything below that validates, in order: typecheck, addons, Lua syntax, XML schema, formatting. Run it before finishing a change.                                                                                                 |
| `npm run format`                   | Prettier (`.prettierrc.json`, `.prettierignore`) on TS/JSON/Markdown/YAML, then StyLua (`stylua.toml`, `.styluaignore`) on Lua. Leaves XML to the editor. `npm run format:check` only reports.                                      |
| `npm run check:addons`             | Every TOC load entry exists (a `[TextLocale]` entry for every client language), `Details_TWW_*` companions depend on `Details_TWW`, no dependency cycles.                                                                           |
| `npm run check:lua`                | `luac -p` on every addon Lua file (needs a Lua 5.1 `luac` on PATH).                                                                                                                                                                 |
| `npm run check:xml`                | Validates every addon XML against Blizzard's `UI.xsd` via python + lxml; skipped when `../_data/BlizzardInterfaceCode` is absent.                                                                                                   |
| `npm run typecheck`                | `tsc --noEmit` on `src/`.                                                                                                                                                                                                           |
| `npm run dev:link -- <AddOns dir>` | Symlink (junction on Windows) every addon into a client; refuses to replace a path that isn't already our link.                                                                                                                     |
| `npm run package:addons`           | Deterministic `dist/Details_TWW-<version>.zip` of all addons (gitignored), without `CLAUDE.md` files.                                                                                                                               |
| `npm run package:local`            | The BigWigs packager the release workflows use (`.pkgmeta`), run locally without uploading: addon folders and zip in `.release/` (gitignored). Extra `release.sh` options go after `--`. On Windows it needs Git for Windows' bash. |

Static checks also used ad hoc: `lua-language-server --check` (config in `.luarc.json`; `lib/` is
excluded from LuaLS, StyLua and Prettier).

## Tooling (`src/`)

ESM with `.js` extensions in relative imports; `tsx` runs the `.ts` directly; strict `tsc`.

- `config.ts` — `ROOT`, `CLIENT_LOCALES` (every `[TextLocale]` value), `packageName()` (the
  `package-as` of `.pkgmeta`, used for zip names and as the main addon's name).
- `addons.ts` — `addonDirectories()` (every direct child with a same-named `.toc`),
  `addonVersion`, `walkFiles`.
- `check-addons.ts`, `check-lua.ts`, `check-xml.ts`, `link-addons.ts`, `package-addons.ts`,
  `package-local.ts` — one per `npm run` script above.
- `zip.ts` — `createZip` (stored, fixed timestamps), `directoryEntries`, `fileNamePart` (a TOC
  version as a file name), shared by the two packaging scripts.

## Releases

`.github/workflows/` runs the BigWigs packager on a pushed `v*` tag (`release-tag.yml`) and from
Actions > Run workflow (`release.yml`, `beta.yml`, `alpha.yml`, which tag the head of `main`
first); all four call `package.yml`. The tag decides the type: `v1.1.0-beta1` is a beta,
`v1.1.0-alpha1` an alpha, anything else a release. `## Version: @project-version@` in the TOC is
filled in by the packager.

What goes into the zip is set by `.pkgmeta` — **a new root file or folder that is not an addon
must be added to its `ignore` list**, or it ships inside the addon's folder. Uploads need the
repository secrets `CF_API_KEY`, `WAGO_API_TOKEN`, `WOWI_API_TOKEN` and the project ids in the TOC
(`## X-Curse-Project-ID`, `## X-Wago-ID`, `## X-WoWI-ID`); a site without both is skipped.

## WoW addon constraints

- Lua 5.1 with Blizzard's restricted API. No `require`, `io`, `os`, or `loadstring` of external
  files; every code file must be listed in its addon's TOC, in dependency order, or it will not
  load.
- Addons share one global namespace. Keep state in the private table passed to each file. A file
  that uses it starts with

  ```lua
  ---@type string, Details_TWW
  local appName, app = ...
  ```

  (`local _, app = ...` when the name is unused, or LuaLS flags it). The `---@type` line gives the
  language server completion on `app.*`. When a file adds a member to `app`, add a matching
  `---@field` to `Details_TWW/src/types.lua`.

- The only sanctioned globals are the SavedVariables tables and XML-required mixins/frames, which
  are prefixed `Details_TWW…`.
- Persistent state lives only in tables declared via `## SavedVariables`; they are populated after
  `ADDON_LOADED`, not at file-load time (AceDB `OnInitialize` is the first safe place).
- Ace3 types (`AceAddon`, `AceDBObject-3.0`, `AceDB.Schema`, …) come from the `ketho.wow-api`
  VS Code extension (`.vscode/settings.json` → `Lua.workspace.library`), not from `lib/`;
  inherit from them rather than redeclaring the API.

## XML files

Every XML file starts with `<Ui xmlns="http://www.blizzard.com/wow/ui/">` and **no**
`xsi:schemaLocation` — the client ignores it and a wrong path makes the VS Code XML extension
report errors. Schema validation comes from `xml.fileAssociations` in `.vscode/settings.json`
(mapping `**/*.xml` to `../_data/BlizzardInterfaceCode/.../Blizzard_SharedXML/UI.xsd`) and from
`npm run check:xml`. Lua mixin files must be listed in the TOC _before_ the XML that references
them.

## Files with backslashes

Lua strings for texture paths need `\\` (`"Interface\\Icons\\INV_Misc_Bag_10"`). Shell heredocs
and inline Python strip the doubled backslash; write such files with the Write/Edit tools (or a
script file with raw strings).

## Reference material (read, never edit, never copy into a TOC)

### Blizzard UI source: `E:\Projects\InterfaceExport\_files`

Exported Blizzard UI code (`Interface\AddOns\Blizzard_*`) from every current client, each on its
latest version. Use it to check API signatures, return values, event payloads, globals, mixins and
templates per client instead of relying on memory. Grep across clients to see whether something
exists on each flavor, since this addon targets all of them.

```text
_files/
  wow/                   Retail (12.x)
  wow_classic/           Mists Classic
  wow_anniversary/       Anniversary (TBC)
  wow_classic_era/       Classic Era
  wowf/                  WoW Forever
  wow_classic_beta/      Classic beta
  wow_classic_beta_art/  Classic beta art assets (Interface/<ART folders>, no AddOns/)
  <client>/Interface/AddOns/Blizzard_*/...
```

- `<client>/Interface/AddOns/Blizzard_APIDocumentationGenerated/*.lua` is the machine-readable API
  documentation (`C_*` namespaces, events, enums). For example, `wow/.../DamageMeterDocumentation.lua`
  documents Blizzard's own damage meter API.
- `npm run check:xml` and the VS Code XML schema still look for `../_data/BlizzardInterfaceCode`,
  which does not exist here, so XML validation is skipped. `UI.xsd` is at
  `<client>/Interface/AddOns/Blizzard_SharedXML/UI.xsd` in the export.

### Details! source

The export holds no Details! code. The installed copy is at
`D:\Spiele\World of Warcraft\_retail_\Interface\AddOns\Details\` (one package for every flavor, with
`Details.toc`, `Details_Mists.toc`, `Details_TBC.toc`, `Details_Classic.toc` and `Details_Camelot.toc`).
Check Details internals there (skin API, instance/line objects, profile import) or in code the user
provides.

### Legacy addon: `legacy/`

The pre-2.0 addon (last code change 2024-08-30, TWW 11.0; afterwards only TOC bumps up to 11.2.5).
It is not loaded or packaged (`.pkgmeta` ignores it; LuaLS, StyLua and Prettier skip it). Use it as a
feature list and a source of values, not as code to copy wholesale.

- `legacy/Core.lua` registers 3 LibSharedMedia statusbar textures (`TheWarWithinHeader`,
  `TheWarWithinBar`, `TheWarWithinBackground`; the registered paths end in `.tga` but the files are
  `.blp`). It installs the skin with `Details:InstallSkin(name, skinTable)` once `Details.IsLoaded()`
  is true after `PLAYER_LOGIN`, then calls `instance:ChangeSkin()` on active instances so the title bar
  applies. On retail it re-textures and tints the Evoker Augmentation `line.extraStatusbar` (existing
  lines and new ones through `hooksecurefunc(Details.gump, "CreateNewLine", ...)`, found by
  `DetailsBarra_<meu_id>_<index>`). `/tww import` imports the default profile.
- The `skinTable` in `legacy/Core.lua` holds the skin values: anchors, title bar (32px), rows
  (28px), fonts, the class/spec icon files and texture names.
- `legacy/Profile_Default.lua` is a Details profile export string (`/tww import`), in the 2024
  Details profile format.
- `legacy/Textures/` holds the skin's own art: `header`, `bar`, `background`, `augment`,
  `ClassIconsTWW`, `specs`. They move into `Details_TWW/assets/` when the feature using them is ported.
- `legacy/Libs/` is the old embedded Ace3 + LibSharedMedia-3.0. `Details_TWW/lib/` has its own
  LibSharedMedia-3.0 (Details!' current copy).

Everything in it that touched Details internals (`instance.ativa`, `instance.meu_id`,
`Details.gump.CreateNewLine`, `line.extraStatusbar`, the skin table keys) has to be checked against
current Details before reuse.

## Textures and frames

- This addon is a skin, so it ships its own textures (from `legacy/Textures/`). Beyond those,
  prefer the game's own textures and atlases, and ask before drawing anything new. The client does
  not load `.png`.
- Change Details through its own API (`Details:InstallSkin`, instance methods) and
  `hooksecurefunc`. Never replace Details or Blizzard functions.
- Don't hard-reference Blizzard frames that exist on only some clients. Check each target client
  in the export first.
- A screenshot the user shares is a look reference, not a template to reproduce pixel by pixel.
