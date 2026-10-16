# Everybody Has a Secret — architecture contract (v1)

Full design brief: `PROMPT.md` (same folder). This file is the CONTRACT between the three builders
(MAP, SERVER, CLIENT). Names, attributes, remotes and payloads below are fixed — do not rename them.
If you need something not listed, add it in your own files and note it in your report.

Project root: `./secret_game`
Rojo layout (`default.project.json`, already present):
- `src/server`  -> ServerScriptService      (SERVER builder; MAP builder owns `src/server/Map/`)
- `src/shared`  -> ReplicatedStorage        (shared modules, see ownership below)
- `src/client`  -> StarterPlayer.StarterPlayerScripts (CLIENT builder)
Tools: `./tools/rojo.exe`, `luau-compile.exe` (`--binary f > /dev/null` syntax check),
`luau.exe` (offline tests), `luau-analyze.exe`. Shell = git-bash; pass `C:/...` paths to the exes.
Build: `cd ./secret_game && ../tools/rojo.exe build default.project.json -o EveryoneHasASecret.rbxlx`
Do NOT open Roblox Studio or any GUI. Do not edit files owned by another builder.

## 0. Scope of v1 (playable, polished vertical slice of the whole brief)
Round loop Lobby → Intro(secret card) → Play(10 min; 1–3 random events; final-minute warning) → Reveal → Rewards → next round, ~20 s downtime.
Works with 1 real player: 9 BOTS (R15 NPC "guests") fill the server up to 10 participants; bots get secrets, act on them,
can be accused, appear in the reveal. Real players replace bots (target 12–24 total, max server 24).
Secrets: main + side per player, 4 tiers, connected STORY CHAINS (Golden Statue etc.), player-targeted objectives,
anti-repeat. Evidence, cameras, footage deletion, framing, accusations with penalties, security guards + 20 s detention,
power outage/lockdown/storm/jackpot/VIP/kitchen fire/police/boat events. Coins, XP, levels+titles, daily/weekly challenges,
stats, DataStore save. Cosmetic shop (coins) + Robux products with id 0 placeholders (button hidden while id == 0).
Tutorial for first-time players (fake secret: "Visit the casino and talk to the dealer").

## 1. World contract (MAP builds it; SERVER/CLIENT only read it)
Everything under `workspace.Resort` (Model). Built at runtime by `src/server/Map/MapBuilder.luau` (module, `.Build()` returns when done,
sets `workspace:SetAttribute("MapReady", true)` at the end). Anchored Parts only, no external asset ids except sounds listed in
`src/shared/Sfx.luau` (MAP owns ambience ids there).

### 1a. Zones — `workspace.Resort.Zones` (Model, ModelStreamingMode = Persistent)
Invisible (Transparency 1), CanCollide/CanQuery/CanTouch false, anchored box Parts. Several parts may share a zone.
Each part: Name = zone id, attributes `ZoneId` (string), `DisplayName` (string), `Outdoor` (bool), `Restricted` (bool).
Fixed zone ids (all must exist):
`Plaza` (pre-round lobby + fountain, spawn), `Lobby` (hotel lobby + reception desk), `Reception` (behind desk, restricted),
`GuestRooms` (2nd floor hallway + 4 rooms), `Balcony`, `Rooftop`, `HotelBar`, `Restaurant` (dining), `PrivateDining` (restricted),
`Kitchen` (incl. freezer, staff entrance, delivery door), `Housekeeping` (incl. storage room, restricted),
`SecurityRoom` (restricted), `Detention` (small cell inside security wing), `Casino` (floor: slots + card tables + prize counter + cashier),
`CasinoVIP` (restricted), `CasinoBackRoom` (restricted), `Pool`, `ChangingRooms`, `PoolBar`, `Beach`, `Dock`, `BeachShop`,
`ShopStreet` (clothing + souvenir + general store fronts), `JewelryShop`, `Underground` (maintenance tunnels + storage),
`ElectricalRoom` (underground, restricted), `HiddenRoom` (secret room in the underground, reached by a secret switch).
`src/shared/Zones.luau` (MAP owns): `return { list = { {id=, name=, outdoor=, restricted=, center=Vector3, icon="🎰"} ...}, byId = {...} }`
— pure data, the SERVER secret generator and CLIENT minimap use it. Keep centers in sync with the built map.

### 1b. Interactables — tag `Interact` (CollectionService) on a BasePart (the prompt host)
Attributes on the part: `Kind` (below), `Id` (unique string), `Zone` (zone id), `Label` (short UI text), optional extras.
SERVER creates the ProximityPrompts and all logic; MAP only places tagged parts.
Kinds and extra attributes:
- `Door` — the door slab itself. `Lock` = "none" | "key:<ItemId>" | "code" | "security" | "secret". `Code` (4 digits) for code doors.
  Optional `Inside` = "+" | "-": the side of the door plane (local Z for x-axis doors, local X for z-axis doors) the room is on;
  SERVER opens such a door for free from the inside (never for `secret` locks or Detention), also during a lockdown.
  SERVER opens a door by tweening it (CanCollide off while open). Restricted zones' entrances are locked doors.
  Note a `code` door's code is written somewhere findable: a part tagged `Interact` with Kind `Note`, attribute `Text`.
- `Search` — drawers, cabinets, boxes, bags, lockers, bins. Optional `Loot` = ItemId (fixed loot) else random from server table.
- `Hide` — closets, changing booths, bins: player can hide inside (invisible, can't move) / hide carried item here (`HideItem` spot).
- `Computer` — `Role` = "Security" (monitor: cameras, footage, access logs, door controls, alarm) | "Reception" (guest list / master key log) | "Casino".
- `Camera` — security camera body. `CamId`, part's LookVector = view direction. SERVER detection: within 60 studs, 70° cone, raycast LOS.
- `PowerBox` — electrical room breaker (SERVER can trigger a power outage for 60 s).
- `Alarm` — alarm button (triggers lockdown/alert).
- `Phone` — lobby/room phones (prank call = distraction: guards walk to the phone zone).
- `Slot` — slot machine. `Cards` — card table (dealer NPC nearby). `Prize` — prize counter. `Cashier`.
- `Food` — restaurant / bar order counter. `Shop` — shop counter, attribute `ShopId` = "Clothing"|"Souvenir"|"General"|"Jewelry"|"Beach".
- `Dig` — beach dig spots (bury / dig up an item). `Boat` — boat at the dock (escape objective, only during BoatArrival event or with key).
- `Switch` — hidden switch; attribute `Opens` = door Id (Lock "secret"). `Elevator` — `To` = another Elevator Id (teleport).
- `Pedestal` — item display (Golden Statue pedestal in the Lobby, necklace case in JewelryShop). attribute `ItemId`.
- `Note` — readable note/sign, attribute `Text`.
- `Board` — lobby notice board (shows current incidents).
Counts (minimum): 28 Doors (all restricted entrances + guest rooms), 30 Search, 10 Hide, 3 Computer (Security, Reception, Casino),
10 Camera (covering Lobby, Casino, CasinoVIP, JewelryShop, Pool, Restaurant, GuestRooms hall, Dock, ShopStreet, Kitchen),
1 PowerBox, 2 Alarm, 4 Phone, 6 Slot, 2 Cards, 1 Prize, 1 Cashier, 3 Food, 5 Shop, 4 Dig, 1 Boat, 2 Switch, 4 Elevator (2 pairs ground↔floor2, floor2↔rooftop), 2 Pedestal, 4 Note, 1 Board.

### 1c. Markers — `workspace.Resort.Markers` (Folder) of invisible anchored parts
- `SpawnPlaza_1..12` (round start points around the Plaza), `LobbySpawn` (SpawnLocation part, real SpawnLocation class, in Plaza).
- `ItemSpawn_*` (attribute `Zone`) — 30 spots spread over all zones where SERVER drops random loot.
- `NPC_<Role>` with attribute `Role`: Dealer, Receptionist, Chef, Bartender, Lifeguard, Cashier, Shopkeeper, Janitor, DoorGuard (by SecurityRoom).
- `GuardPath_<n>_<k>` patrol waypoints for 3 guards (n = 1..3, k = 1..6), floor-level.
- `DetentionCell` (inside Detention zone), `DetentionExit`.
- `VIPArrive`, `PoliceArrive` (Plaza edge), `BoatDock` (end of dock), `FireSpot` (kitchen).
- `BotWander_*` 25 walkable points spread across zones (attribute `Zone`) for bot navigation.
All markers sit 3 studs above the walkable floor. All floors walkable for a Humanoid (PathfindingService friendly: no gaps, ramps/stairs
≤ 35°, door gaps ≥ 6 studs wide, 10 studs tall).

### 1d. Lighting / FX hooks
- Tag `ResortLight` on every PointLight/SpotLight parent part (SERVER turns them off in power outage). Neon light fixtures: tag `ResortNeon`.
- Kitchen fire: MAP places a disabled `Fire` + `ParticleEmitter` under part `Markers.FireSpot` (SERVER enables).
- Storm: SERVER handles (Lighting + rain ParticleEmitter attached to camera by CLIENT).
- `src/server/Map/Lighting.luau` (MAP) sets bright tropical day lighting: Atmosphere, Bloom, ColorCorrection, SunRays, Sky. Not dark.

## 2. Items (Tools) — `src/shared/Items.luau` (SERVER owns data) + `src/shared/ItemArt.luau` (MAP owns art)
`ItemArt.build(itemId) -> BasePart "Handle"` (≤ 12 parts welded to Handle, unanchored, Massless). SERVER wraps it in a Tool
(Name = display name, CanBeDropped = false, attribute `ItemId`). Fixed ids:
GoldenStatue, DiamondNecklace, VIPKeycard, SecurityCard, MasterKey, CasinoChip, Briefcase, PhotoCamera, StaffUniform,
Crowbar, TreasureMap, SecretLetter, Champagne, Pizza, Flashlight (exactly these 15).
Effects (SERVER): SecurityCard opens Lock="security"; MasterKey opens any GuestRooms door + Housekeeping; VIPKeycard opens CasinoVIP;
Crowbar forces any non-security door (loud: creates `BrokenDoor` evidence + alerts guards); StaffUniform = disguise 60 s
(cameras/guards ignore you, name tag hidden); PhotoCamera = take photo; Flashlight = see during outage; others are objective items.
Stolen-flag: an item picked from a Pedestal/another player is "hot" — carrying it in view of a camera/guard = detection.

## 3. Remotes — SERVER creates `ReplicatedStorage.Remotes` (Folder) on start; CLIENT uses WaitForChild
Server→Client RemoteEvents (payload = one table):
- `RoundState` {phase="Lobby"|"Intro"|"Play"|"Reveal"|"Rewards", endsAt=number (workspace:GetServerTimeNow()), round=int, warning=bool}
- `YourSecret` {main=Obj, side=Obj, role=string ("THE THIEF"), reward=int, rerollsLeft=int, tutorial=bool}
   Obj = {id=string, tier="Easy"|"Medium"|"Hard"|"Legendary", text=string, steps={string...} (optional sub-steps),
          step=int, progress={cur=int,max=int} (optional), done=bool, failed=bool, hintZone=string? (zone id for arrow)}
- `SecretProgress` {slot="main"|"side", obj=Obj}              (full Obj re-sent on change)
- `Toast` {text=string, kind="info"|"good"|"bad"|"event"|"evidence"|"security"|"social", sfx=string?}
- `EventBanner` {id=string, title=string, desc=string, icon=string, duration=number}
- `Incident` {list={{id=string, title=string, zone=string, time=number, solved=bool}}}   (public incidents e.g. "Golden Statue stolen")
- `Evidence` {list={{id, kind="Footage"|"Footprints"|"Dropped"|"Missing"|"Witness"|"AccessLog"|"BrokenDoor"|"Transaction"|"Photo",
              text=string, zone=string, time=number, suspects={userId...} (0–3 ids, may include innocents), incident=string?}}}
   (personal evidence journal of THIS player; sent whole on change)
- `Monitor` {cams={{id, name, online=bool}}, footage={{id, text, time, deleted=bool}}, logs={{text,time}}, canDelete=bool, canDisable=bool}
- `ViewCam` {camId=string, cframe=CFrame}   (client switches Camera to it until closed)
- `Keypad` {doorId=string}                  (client shows 4-digit keypad)
- `Request` {requestId=string, fromUserId=int, fromName=string, kind="TeamUp"|"Follow"|"Trade"|"Give", detail=string}
- `Allies` {list={userId...}}
- `Detained` {untilTime=number, reason=string}  (untilTime 0 = released)
- `Reveal` {rows={{userId=int, name=string, isBot=bool, role=string, color=Color3,
             main={text, tier, done}, side={text, done}, reward=int, highlights={string...}}}, mvp=int, story=string}
- `Rewards` {coins=int, xp=int, level=int, leveledUp=bool, title=string, breakdown={{label, coins, xp}}}
- `Profile` {coins, level, xp, xpNext, title, stats={...}, daily={{id,text,cur,max,done,reward}}, weekly={...},
            owned={id=true}, equipped={Hat=, Trail=, Title=, NameFx=}, vip=bool, firstTime=bool}
- `Sfx` {name=string, pos=Vector3?}         (names in `src/shared/Sfx.luau`)
- `Photo` {targetName=string?, caught=string?}  (flash + polaroid toast)
Client→Server:
- RemoteEvent `Action` (action:string, args:table) — EVERYTHING validated on server. Actions:
  "Accuse" {targetId=int(userId or negative bot id), incident=string}, "TakePhoto" {}, "DeleteFootage" {id}, "DisableCam" {camId},
  "ViewCam" {camId}, "CloseMonitor" {}, "EnterCode" {doorId, code}, "SocialRequest" {targetId, kind, detail?}, "Respond" {requestId, accept},
  "GiveCoins" {targetId, amount}, "DropItem" {}, "Buy" {id}, "Equip" {slot, id}, "Reroll" {slot}, "Ready" {} (client loaded),
  "TutorialDone" {}, "Emote" {name}
- Bots have negative ids (-1..-9) everywhere a userId is used; names like "Guest_Mia". CLIENT must handle negative ids (no thumbnails).
  Bot models live in `workspace.EHAS_Bots` (Model per bot, attribute `BotId` = the negative id); CLIENT finds them via `U.botsFolder()`.

## 4. Shared modules
- `src/shared/Sfx.luau` (MAP owns): `return { [name] = {id="rbxassetid://..", vol=0.6} }`. Required names: Ambient_Hotel, Ambient_Casino,
  Ambient_Beach, Ambient_Underground, Ambient_Security, Ambient_Pool, Music_Lobby, Music_Reveal, SecretGet, Progress, Complete, Fail,
  Evidence, Detected, Alarm, Event, Countdown, Click, DoorOpen, Locked, Photo, CoinGet, LevelUp, VineBoom, Bruh, Whoosh, Jackpot, Thunder.
  Ids: verified public assets from the toolbox search API (creators ProSoundEffects/APMOfficial/Roblox for music/ambience; any public for memes).
- `src/shared/Config.luau` (SERVER owns): timings, rewards, level table (1 Rookie, 5 Guest, 10 Suspect, 15 Insider, 25 Detective, 35 Agent,
  50 Mastermind, 75 Phantom, 100 Legend), xpForLevel(n), tier rewards (Easy 60c/40xp, Medium 120/80, Hard 220/150, Legendary 400/300; side = 50%),
  accuse rewards/penalties, detention 20 s.
- `src/shared/ShopConfig.luau` (SERVER owns): cosmetics (hats, trails, titles, name effects, masks, victory emotes) with coin prices and
  Robux products/passes with `ProductId = 0` / `PassId = 0` placeholders: SecretReroll 25 R$ (max 2/round), VIP pass 199, 2x XP pass 149,
  StarterPack 49, packs (Detective/Mastermind/Casino/Luxury/Spy) 99–149, Mystery Crate 35 (cosmetics only, odds shown).
- `src/shared/Items.luau` (SERVER owns): {[id]={name, desc, icon (emoji)}}

## 5. SERVER builder files (`src/server/`)
`Main.server.luau` (boot: MapBuilder.Build → services → round loop), `Bus.luau` (tiny signal hub: Bus.fire(name, ...)/Bus.on(name, fn)),
`Data.luau` (profiles, DataStore "EHAS_v1", UpdateAsync + seq, pcall, never overwrite on failed load, leaderstats Coins/Level),
`Round.luau`, `SecretDB.luau` (PURE Luau, no Instances: templates + chain generator, `SecretDB.generate(participants, zones, rng, recent)`
→ assignments; testable with luau.exe), `Secrets.luau` (assign + track + verify via Bus events), `Interact.luau` (prompts, doors, search,
items/tools, hide, elevators, switches, keypad), `Security.luau` (cameras, footage records, access logs, guards NPC patrol/chase/detain,
detention), `Evidence.luau`, `Events.luau` (random events), `Accuse.luau`, `Social.luau` (requests, alliances, follow tracking, give coins,
talk counting), `Bots.luau` (9 R15 bots with secrets, PathfindingService between BotWander/targets, do objectives, sometimes accuse),
`Shop.luau` (coins + MarketplaceService, ProcessReceipt), `Progress.luau` (XP, levels, daily/weekly challenges, stats, leaderboards OrderedDataStore),
`SelfTest.server.luau` (runs when workspace attribute `RunSelfTest` or no player within 5 s in Studio; prints `SELFTEST PASS:/FAIL:` and `SELFTEST DONE n passed, m failed`).
Offline test: `tests/secretdb_test.luau` run with `luau.exe` — generate for 1..24 participants × 200 seeds: every participant gets main+side,
chains reference only existing participants, no participant targets itself, tier mix sane, anti-repeat works.

## 6. CLIENT builder files (`src/client/`)
HUD (phase + timer top-center, coins/level top-left under Roblox buttons, 🔒 SECRET button bottom-left, journal 🔍 button, accuse ⚖️ button,
map 🗺️ button), SecretCard (big animated reveal at Intro, then collapsible), Reveal screen (dramatic one-by-one cards, colored by tier,
✅/❌, MVP, "PLAY AGAIN" auto), Rewards panel, Evidence journal, Accuse menu (pick incident → pick suspect from player+bot list → confirm),
Monitor UI (camera list → ViewCam, footage list with DELETE, logs, disable cam), Keypad, Request popup (Accept/Decline), Minimap
(top-right is Roblox's player list → put minimap bottom-right above jump area, small, toggle big map), zone label on entering a zone
("🎰 CASINO"), objective arrow to `hintZone`, toasts, event banners, detention overlay with countdown, tutorial overlay (5 steps),
Shop/Profile UI (cosmetics, daily/weekly, stats), photo flash, power-outage darkness + flashlight cone client FX, storm rain FX,
zone ambience crossfade, mobile buttons (Photo, Drop item, Hide). HudScale UIScale = clamp(min(viewport)/1080, 0.4, 1) on every ScreenGui,
IgnoreGuiInset=false; nothing permanently covering the middle of the screen. Fonts GothamBold/FredokaOne, UICorner+UIStroke, tweens.

## 7. Style rules (all)
Bright luxury tropical resort, colorful and detailed — NOT dark/horror. Mobile-first. Server-authoritative. pcall around DataStore/Marketplace.
No `wait()` — use `task.*`. No external meshes/decals. Keep total map parts ≤ 9000.
