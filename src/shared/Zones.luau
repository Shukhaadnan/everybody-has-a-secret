-- Zones.luau (MAP owns): pure data. Centers are walk-level points inside each built zone (see src/server/Map/MapBuilder.luau ZONE_BOXES).
local list = {
	{ id = "Plaza", name = "Resort Plaza", outdoor = true, restricted = false, center = Vector3.new(0, 7, 22), icon = "⛲" },
	{ id = "Lobby", name = "Hotel Lobby", outdoor = false, restricted = false, center = Vector3.new(0, 7, -40), icon = "🏨" },
	{ id = "Reception", name = "Reception Office", outdoor = false, restricted = true, center = Vector3.new(0, 7, -85), icon = "🛎️" },
	{ id = "GuestRooms", name = "Guest Rooms", outdoor = false, restricted = false, center = Vector3.new(0, 24, -53), icon = "🛏️" },
	{ id = "Balcony", name = "Balcony", outdoor = true, restricted = false, center = Vector3.new(0, 24, -3), icon = "🌅" },
	{ id = "Rooftop", name = "Rooftop Lounge", outdoor = true, restricted = false, center = Vector3.new(10, 41, -70), icon = "🚁" },
	{ id = "HotelBar", name = "Sunset Bar", outdoor = false, restricted = false, center = Vector3.new(-42, 7, -30), icon = "🍸" },
	{ id = "Restaurant", name = "La Palma Restaurant", outdoor = false, restricted = false, center = Vector3.new(118, 7, -42), icon = "🍽️" },
	{ id = "PrivateDining", name = "Private Dining", outdoor = false, restricted = true, center = Vector3.new(105, 7, -85), icon = "🕯️" },
	{ id = "Kitchen", name = "Kitchen", outdoor = false, restricted = false, center = Vector3.new(150, 7, -82), icon = "👨‍🍳" },
	{ id = "Housekeeping", name = "Housekeeping", outdoor = false, restricted = true, center = Vector3.new(-40, 7, -75), icon = "🧺" },
	{ id = "SecurityRoom", name = "Security Room", outdoor = false, restricted = true, center = Vector3.new(36, 7, -80), icon = "📹" },
	{ id = "Detention", name = "Detention Cell", outdoor = false, restricted = true, center = Vector3.new(53, 7, -94), icon = "🚔" },
	{ id = "Casino", name = "Palm Arcade", outdoor = false, restricted = false, center = Vector3.new(-130, 7, -45), icon = "🕹️" },
	{ id = "CasinoVIP", name = "Arcade VIP Lounge", outdoor = false, restricted = true, center = Vector3.new(-155, 7, -82), icon = "👑" },
	{ id = "CasinoBackRoom", name = "Arcade Back Room", outdoor = false, restricted = true, center = Vector3.new(-115, 7, -85), icon = "💰" },
	{ id = "Pool", name = "Infinity Pool", outdoor = true, restricted = false, center = Vector3.new(125, 7, 16), icon = "🏊" },
	{ id = "ChangingRooms", name = "Changing Rooms", outdoor = false, restricted = false, center = Vector3.new(170, 7, 21), icon = "🚿" },
	{ id = "PoolBar", name = "Tiki Pool Bar", outdoor = true, restricted = false, center = Vector3.new(162, 7, 60), icon = "🍹" },
	{ id = "Beach", name = "Palm Beach", outdoor = true, restricted = false, center = Vector3.new(0, 4, 122), icon = "🏖️" },
	{ id = "Dock", name = "Marina Dock", outdoor = true, restricted = false, center = Vector3.new(100, 7, 150), icon = "⚓" },
	{ id = "BeachShop", name = "Surf & Sun Shop", outdoor = true, restricted = false, center = Vector3.new(-100, 7, 100), icon = "🏄" },
	{ id = "ShopStreet", name = "Shop Street", outdoor = true, restricted = false, center = Vector3.new(-130, 7, 30), icon = "🛍️" },
	{ id = "JewelryShop", name = "Diamond & Pearl Jewelry", outdoor = false, restricted = false, center = Vector3.new(-160, 7, 66), icon = "💎" },
	{ id = "Underground", name = "Maintenance Tunnels", outdoor = false, restricted = false, center = Vector3.new(0, -9, -34), icon = "🚇" },
	{ id = "ElectricalRoom", name = "Electrical Room", outdoor = false, restricted = true, center = Vector3.new(43, -9, -50), icon = "⚡" },
	{ id = "HiddenRoom", name = "Hidden Room", outdoor = false, restricted = true, center = Vector3.new(2, -9, -56), icon = "🗝️" },
}

local byId = {}
for _, z in ipairs(list) do
	byId[z.id] = z
end

return { list = list, byId = byId }
