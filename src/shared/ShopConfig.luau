-- ShopConfig.luau (SERVER owns; CLIENT reads for the shop UI).
-- Cosmetics only — nothing here changes gameplay (brief §35/§51).
-- Robux ids are 0 placeholders: the server skips the purchase prompt while an id is 0 and the
-- client hides the button.
local ShopConfig = {}

-- slot: Hat | Trail | Title | NameFx | Mask | Victory
-- rarity: Common | Uncommon | Rare | Epic | Legendary (crate odds use it)
-- art (server builds cosmetics from parts; RGB arrays keep this module pure data)
ShopConfig.Cosmetics = {
	-- HATS (Accessory built from parts)
	{ id = "Hat_TopHat", slot = "Hat", name = "Top Hat", price = 250, rarity = "Common", art = { style = "tophat", color = { 25, 25, 30 }, accent = { 200, 30, 40 } } },
	{ id = "Hat_Fedora", slot = "Hat", name = "Spy Fedora", price = 350, rarity = "Uncommon", art = { style = "fedora", color = { 60, 50, 45 }, accent = { 20, 20, 20 } } },
	{ id = "Hat_DetectiveCap", slot = "Hat", name = "Detective Cap", price = 0, rarity = "Rare", reward = true, art = { style = "cap", color = { 150, 115, 70 }, accent = { 90, 65, 40 } } },
	{ id = "Hat_Crown", slot = "Hat", name = "Golden Crown", price = 1500, rarity = "Epic", art = { style = "crown", color = { 245, 200, 60 }, accent = { 220, 40, 60 } } },
	{ id = "Hat_Beret", slot = "Hat", name = "Artist Beret", price = 200, rarity = "Common", art = { style = "beret", color = { 200, 40, 60 }, accent = { 30, 30, 30 } } },
	{ id = "Hat_SunHat", slot = "Hat", name = "Resort Sun Hat", price = 180, rarity = "Common", art = { style = "sunhat", color = { 235, 215, 160 }, accent = { 70, 170, 220 } } },
	{ id = "Hat_Halo", slot = "Hat", name = "Innocent Halo", price = 900, rarity = "Rare", art = { style = "halo", color = { 255, 240, 140 }, accent = { 255, 255, 255 } } },
	{ id = "Hat_Chef", slot = "Hat", name = "Chef Hat", price = 300, rarity = "Uncommon", art = { style = "chef", color = { 250, 250, 250 }, accent = { 230, 230, 230 } } },
	-- TRAILS
	{ id = "Trail_Gold", slot = "Trail", name = "Gold Dust", price = 400, rarity = "Uncommon", art = { c0 = { 255, 215, 80 }, c1 = { 255, 170, 40 } } },
	{ id = "Trail_Neon", slot = "Trail", name = "Neon Night", price = 600, rarity = "Rare", art = { c0 = { 80, 220, 255 }, c1 = { 220, 80, 255 } } },
	{ id = "Trail_Shadow", slot = "Trail", name = "Shadow Step", price = 800, rarity = "Rare", art = { c0 = { 40, 40, 50 }, c1 = { 120, 60, 160 } } },
	{ id = "Trail_Phantom", slot = "Trail", name = "Phantom Mist", price = 0, rarity = "Legendary", reward = true, art = { c0 = { 200, 200, 255 }, c1 = { 255, 255, 255 } } },
	{ id = "Trail_Casino", slot = "Trail", name = "Pixel Trail", price = 700, rarity = "Rare", art = { c0 = { 230, 40, 40 }, c1 = { 40, 160, 60 } } },
	-- TITLES (shown above the head)
	{ id = "Title_Innocent", slot = "Title", name = "Totally Innocent", price = 150, rarity = "Common" },
	{ id = "Title_Liar", slot = "Title", name = "Professional Liar", price = 300, rarity = "Uncommon" },
	{ id = "Title_SharpEye", slot = "Title", name = "Sharp Eye", price = 0, rarity = "Rare", reward = true },
	{ id = "Title_HighRoller", slot = "Title", name = "Arcade Champ", price = 500, rarity = "Rare" },
	{ id = "Title_Mastermind", slot = "Title", name = "The Mastermind", price = 2000, rarity = "Epic", minLevel = 50 },
	{ id = "Title_NotMe", slot = "Title", name = "It Wasn't Me", price = 250, rarity = "Common" },
	-- NAME EFFECTS (BillboardGui name color / glow)
	{ id = "NameFx_Gold", slot = "NameFx", name = "Golden Name", price = 500, rarity = "Uncommon", art = { color = { 255, 215, 80 }, stroke = { 120, 80, 0 } } },
	{ id = "NameFx_Ice", slot = "NameFx", name = "Ice Name", price = 450, rarity = "Uncommon", art = { color = { 160, 230, 255 }, stroke = { 30, 80, 140 } } },
	{ id = "NameFx_Toxic", slot = "NameFx", name = "Toxic Name", price = 650, rarity = "Rare", art = { color = { 140, 255, 90 }, stroke = { 20, 80, 20 } } },
	{ id = "NameFx_Royal", slot = "NameFx", name = "Royal Name", price = 1200, rarity = "Epic", art = { color = { 200, 120, 255 }, stroke = { 60, 0, 90 } } },
	-- MASKS (Accessory on the face)
	{ id = "Mask_Masquerade", slot = "Mask", name = "Masquerade Mask", price = 400, rarity = "Uncommon", art = { style = "masquerade", color = { 30, 30, 40 }, accent = { 240, 200, 70 } } },
	{ id = "Mask_Bandit", slot = "Mask", name = "Bandit Mask", price = 350, rarity = "Uncommon", art = { style = "bandit", color = { 20, 20, 25 }, accent = { 20, 20, 25 } } },
	{ id = "Mask_Monocle", slot = "Mask", name = "Fancy Monocle", price = 550, rarity = "Rare", art = { style = "monocle", color = { 240, 200, 70 }, accent = { 200, 230, 255 } } },
	{ id = "Mask_Mustache", slot = "Mask", name = "Fake Mustache", price = 120, rarity = "Common", art = { style = "mustache", color = { 40, 25, 15 }, accent = { 40, 25, 15 } } },
	-- VICTORY EMOTES (played by the client at reveal when you succeed; ids = default R15 emotes)
	{ id = "Victory_Cheer", slot = "Victory", name = "Cheer", price = 0, rarity = "Common", default = true, art = { anim = 507770677 } },
	{ id = "Victory_Dance", slot = "Victory", name = "Dance", price = 300, rarity = "Uncommon", art = { anim = 507771019 } },
	{ id = "Victory_Dance2", slot = "Victory", name = "Groove", price = 500, rarity = "Rare", art = { anim = 507776043 } },
	{ id = "Victory_Laugh", slot = "Victory", name = "Evil Laugh", price = 400, rarity = "Uncommon", art = { anim = 507770818 } },
	{ id = "Victory_Point", slot = "Victory", name = "Gotcha!", price = 250, rarity = "Common", art = { anim = 507770453 } },
	-- VIP-only
	{ id = "Title_VIP", slot = "Title", name = "VIP", price = 0, rarity = "Epic", vip = true },
	{ id = "NameFx_VIP", slot = "NameFx", name = "VIP Gold Glow", price = 0, rarity = "Epic", vip = true, art = { color = { 255, 230, 120 }, stroke = { 180, 110, 0 } } },
}

ShopConfig.byId = {}
for _, c in ipairs(ShopConfig.Cosmetics) do
	ShopConfig.byId[c.id] = c
end

ShopConfig.Slots = { "Hat", "Trail", "Title", "NameFx", "Mask", "Victory" }

-- Robux developer products (consumable) — ProductId 0 = not created yet (no prompt)
ShopConfig.Products = {
	SecretReroll = { ProductId = 0, price = 25, name = "Secret Reroll", desc = "Reroll your main or side secret (max 2 per round)." },
	StarterPack = { ProductId = 0, price = 49, name = "Starter Pack", desc = "500 coins + Starter title + Fedora + Dance emote + 30 min 2x XP.",
		coins = 500, grant = { "Hat_Fedora", "Title_Innocent", "Victory_Dance" }, xpBoostMinutes = 30, once = true },
	DetectivePack = { ProductId = 0, price = 99, name = "Detective Pack", desc = "Detective cap, Sharp Eye title, Monocle.", grant = { "Hat_DetectiveCap", "Title_SharpEye", "Mask_Monocle" } },
	MastermindPack = { ProductId = 0, price = 149, name = "Mastermind Pack", desc = "Crown, Royal name, Evil Laugh.", grant = { "Hat_Crown", "NameFx_Royal", "Victory_Laugh" } },
	CasinoPack = { ProductId = 0, price = 99, name = "Arcade Pack", desc = "Pixel trail, Arcade Champ title, Top Hat.", grant = { "Trail_Casino", "Title_HighRoller", "Hat_TopHat" } },
	LuxuryPack = { ProductId = 0, price = 129, name = "Luxury Pack", desc = "Gold Dust trail, Golden Name, Masquerade mask.", grant = { "Trail_Gold", "NameFx_Gold", "Mask_Masquerade" } },
	SpyPack = { ProductId = 0, price = 119, name = "Spy Pack", desc = "Spy Fedora, Shadow Step trail, Bandit mask.", grant = { "Hat_Fedora", "Trail_Shadow", "Mask_Bandit" } },
	MysteryCrate = { ProductId = 0, price = 35, name = "Mystery Crate", desc = "A random cosmetic (odds shown).", crate = true },
}
ShopConfig.ProductOrder = { "SecretReroll", "StarterPack", "DetectivePack", "MastermindPack", "CasinoPack", "LuxuryPack", "SpyPack", "MysteryCrate" }

-- Game passes — PassId 0 = not created yet
ShopConfig.Passes = {
	VIP = { PassId = 0, price = 199, name = "VIP", desc = "VIP tag, VIP gold name glow, VIP title, +10% coins. No gameplay advantage." },
	DoubleXP = { PassId = 0, price = 149, name = "2x XP", desc = "Double XP from every round." },
}

-- Mystery crate odds (cosmetics only; shown in the UI — Roblox rule for paid random items)
ShopConfig.CrateOdds = {
	{ rarity = "Common", pct = 50 },
	{ rarity = "Uncommon", pct = 28 },
	{ rarity = "Rare", pct = 15 },
	{ rarity = "Epic", pct = 6 },
	{ rarity = "Legendary", pct = 1 },
}
ShopConfig.CrateDuplicateCoins = 150 -- duplicate -> coins

return ShopConfig
