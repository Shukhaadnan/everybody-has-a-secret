-- Items.luau (SERVER owns data; read by CLIENT too). Exactly the 15 contract item ids.
-- hold = how the Tool grip sits in the hand ("bottom" upright objects, "top" carried by a handle,
-- "center" flat/small; default by size). Grip is computed in Core.applyGrip from the art bounds.
-- hot = stolen from a pedestal / another player by default (cameras + guards react).
local Items = {
	GoldenStatue = { hold = "bottom", name = "Golden Statue", desc = "The resort's priceless statue. Everyone wants it.", icon = "🗿", valuable = true },
	DiamondNecklace = { hold = "center", name = "Diamond Necklace", desc = "Sparkling necklace from the jewelry case.", icon = "💎", valuable = true },
	VIPKeycard = { name = "VIP Keycard", desc = "Opens the Arcade VIP room.", icon = "💳" },
	SecurityCard = { name = "Security Card", desc = "Opens security doors (Security Room, Electrical Room).", icon = "🪪" },
	MasterKey = { name = "Master Key", desc = "Opens every guest room and housekeeping.", icon = "🗝️" },
	CasinoChip = { name = "Gold Token", desc = "A rare gold arcade token. Trade it at the prize desk.", icon = "🪙" },
	Briefcase = { hold = "top", name = "Briefcase", desc = "The VIP's briefcase. What's inside?", icon = "💼", valuable = true },
	PhotoCamera = { hold = "center", name = "Photo Camera", desc = "Click to photograph whoever is in front of you.", icon = "📷" },
	StaffUniform = { name = "Staff Uniform", desc = "Equip to disguise yourself as staff for 60 s.", icon = "🦺" },
	Crowbar = { hold = "bottom", name = "Crowbar", desc = "Forces locked doors open. Very loud.", icon = "🔧" },
	TreasureMap = { name = "Treasure Map", desc = "X marks a dig spot on the beach.", icon = "🗺️" },
	SecretLetter = { name = "Secret Letter", desc = "Sealed letter. Someone wants it delivered.", icon = "✉️" },
	Champagne = { hold = "bottom", name = "Sparkling Juice", desc = "A chilled bottle of sparkling juice.", icon = "🧃" },
	Pizza = { hold = "center", name = "Pizza", desc = "Hot pizza from the restaurant.", icon = "🍕" },
	Flashlight = { hold = "bottom", name = "Flashlight", desc = "Lights your way during a power outage.", icon = "🔦" },
}
-- (ordered id list lives in Config.ItemOrder so `pairs(Items)` only yields items)

return Items
