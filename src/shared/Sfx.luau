-- Sfx.luau (MAP owns): sound ids verified live via the Roblox toolbox API (creator + duration checked).
-- Music/ambience only from ProSoundEffects / APMOfficial / Roblox / DistrokidOfficial; meme SFX from public uploads.
local function id(n)
	return "rbxassetid://" .. tostring(n)
end

return {
	-- ambience (looped per zone under workspace.Resort.Ambience.<ZoneId>)
	Ambient_Hotel = { id = id(1843265221), vol = 0.25 }, -- APMOfficial "Hotel Lobby" (piano)
	Ambient_Casino = { id = id(9112816246), vol = 0.35 }, -- ProSoundEffects "Las Vegas Casino 2"
	Ambient_Beach = { id = id(137826155053556), vol = 0.45 }, -- DistrokidOfficial "Ocean waves on the beach"
	Ambient_Underground = { id = id(130108291179653), vol = 0.35 }, -- DistrokidOfficial "Ambience of The Underground"
	Ambient_Security = { id = id(9125446564), vol = 0.3 }, -- ProSoundEffects "Command Room Tone ... Hum"
	Ambient_Pool = { id = id(9113665498), vol = 0.4 }, -- ProSoundEffects "Calm Water Lap 2"
	-- music
	Music_Lobby = { id = id(127251981695845), vol = 0.3 }, -- DistrokidOfficial "Chill Bossa Nova Lounge Music"
	Music_Reveal = { id = id(113950257591875), vol = 0.35 }, -- DistrokidOfficial "Classic Detective (Mystery)"
	-- stings / UI
	SecretGet = { id = id(1835281285), vol = 0.6 }, -- APMOfficial "Discovered Sting"
	Progress = { id = id(9126073001), vol = 0.6 }, -- ProSoundEffects "Synth Sparkle ... Ding"
	Complete = { id = id(1840078221), vol = 0.6 }, -- APMOfficial "Building Success (sting)"
	Fail = { id = id(1839998001), vol = 0.6 }, -- APMOfficial "Wrong Answer 4"
	Evidence = { id = id(1842057299), vol = 0.6 }, -- APMOfficial "Discover the Unknown (sting)"
	Detected = { id = id(9113085764), vol = 0.6 }, -- ProSoundEffects "Alarm Buzzer 5"
	Alarm = { id = id(9125557781), vol = 0.5 }, -- ProSoundEffects "Fire Alarm ... Buzzer"
	Event = { id = id(1836473422), vol = 0.6 }, -- APMOfficial "Victory Fanfare Sting"
	Countdown = { id = id(9117060548), vol = 0.6 }, -- ProSoundEffects "Nasa Transmission Beep 4"
	Click = { id = id(9119717523), vol = 0.5 }, -- ProSoundEffects "Switch Click On Or Off"
	DoorOpen = { id = id(9114153584), vol = 0.6 }, -- ProSoundEffects "Door Slide Open Close 1"
	Locked = { id = id(9116324156), vol = 0.6 }, -- ProSoundEffects "Lock Unlock Door 10"
	Photo = { id = id(17208312548), vol = 0.7 }, -- Roblox "Roblox GUI - Camera Shutter"
	CoinGet = { id = id(127645268874265), vol = 0.6 }, -- Roblox "CoinTransfer_01"
	LevelUp = { id = id(1839901345), vol = 0.6 }, -- APMOfficial "Powered Up Chimes"
	Jackpot = { id = id(1846251193), vol = 0.6 }, -- APMOfficial "Jackpot Mania Win"
	Thunder = { id = id(9120021541), vol = 0.6 }, -- ProSoundEffects "Thunder Sharp Booming Strikes 2"
	-- meme SFX (public uploads found in the toolbox search)
	VineBoom = { id = id(140367458608473), vol = 0.7 }, -- "vine-boom-sound-effect"
	Bruh = { id = id(140007222940724), vol = 0.7 }, -- "bruh sound effect"
	Whoosh = { id = id(12222200), vol = 0.6 }, -- Roblox "swoosh.wav"
	-- extras (optional)
	Seagulls = { id = id(9118858002), vol = 0.3 }, -- ProSoundEffects "Seagulls 1"
	SlotSpin = { id = id(9119221465), vol = 0.5 }, -- ProSoundEffects "Slot Machine 8"
}
