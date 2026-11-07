class_name Data
## The rules of the game. From Android 1.2 these are harder than the Mac version.

enum { SHADE, BAT, BLOB, MINI, SPITTER, BOMBER, BOSS1, BOSS2 }

const ENEMY_TEX := ["shade", "bat", "blob", "mini", "spitter", "bomber", "boss1", "boss2"]
# radius, health, speed, damage, ember value
const ENEMY := [
	[14.0, 6.0, 70.0, 6.0, 1],
	[12.0, 4.0, 134.0, 4.0, 1],
	[24.0, 34.0, 48.0, 10.0, 3],
	[12.0, 7.0, 88.0, 4.0, 1],
	[16.0, 15.0, 56.0, 6.0, 2],
	[16.0, 11.0, 92.0, 0.0, 2],
	[62.0, 1100.0, 95.0, 14.0, 40],
	[78.0, 3600.0, 115.0, 20.0, 80],
]

const WEAPONS := ["bolt", "moths", "nova", "fireflies", "trail", "zap", "starfall"]
const WEAPON_NAME := {
	"bolt": "Spark Bolt", "moths": "Moth Ring", "nova": "Flare Nova", "fireflies": "Fireflies",
	"trail": "Ember Trail", "zap": "Chain Zap", "starfall": "Starfall",
}

const PASSIVES := ["soul", "glow", "feet", "magnet", "rapid", "sharp", "big", "wind", "luck"]
const PASSIVE_NAME := {
	"soul": "Bright Soul", "glow": "Wider Glow", "feet": "Quick Feet", "magnet": "Ember Magnet", "rapid": "Rapid Heart",
	"sharp": "Sharp Sparks", "big": "Big Bang", "wind": "Second Wind", "luck": "Lucky Moth",
}
const PASSIVE_BLURB := {
	"soul": "+15 max light, and heal 15 now.",
	"glow": "See 15% further into the dark.",
	"feet": "Move 9% faster.",
	"magnet": "Pull embers from 40% further away.",
	"rapid": "All weapons fire 9% faster.",
	"sharp": "All weapons deal 15% more damage.",
	"big": "Attacks are 12% bigger.",
	"wind": "When your light dies, relight once.",
	"luck": "More critical hits and rare drops.",
}


static func weapon_blurb(w: String, level: int) -> String:
	match w:
		"bolt":
			if level == 1: return "Fires sparks at the nearest shadow."
			if level == 3 or level == 5: return "One more spark per shot."
			if level == 4: return "Sparks pierce through two shadows."
			return "More damage."
		"moths": return "Moths circle you and bite what they touch." if level == 1 else "One more moth, and more bite."
		"nova": return "A ring of fire that shoves everything away." if level == 1 else "Bigger, stronger and more often."
		"fireflies": return "Homing fireflies hunt shadows for you." if level == 1 else "Faster, and one more firefly every other level."
		"trail": return "You leave burning embers where you walk." if level == 1 else "Hotter embers that last longer."
		"zap": return "Lightning jumps between shadows." if level == 1 else "Jumps further and hits harder."
		"starfall": return "Stars crash down on random shadows." if level == 1 else "Bigger impact, and one more star every other level."
	return ""


static func passive_max(id: String) -> int:
	return 1 if id == "wind" else 5


const FLAMES := [
	{"id": "candle", "name": "Candle", "blurb": "Steady and dependable. Starts with Spark Bolt.",
	 "outer": Color(1.0, 0.48, 0.13), "inner": Color(1.0, 0.85, 0.35), "cost": 0, "start": "bolt", "light": 100.0, "speed": 1.0, "radius": 1.0},
	{"id": "firefly", "name": "Firefly", "blurb": "Fast but fragile. Starts with Fireflies.",
	 "outer": Color(0.45, 0.95, 0.30), "inner": Color(0.90, 1.0, 0.55), "cost": 100, "start": "fireflies", "light": 92.0, "speed": 1.2, "radius": 0.95},
	{"id": "lantern", "name": "Lantern", "blurb": "Slow, huge glow, lots of light. Starts with Flare Nova.",
	 "outer": Color(0.95, 0.30, 0.55), "inner": Color(1.0, 0.75, 0.75), "cost": 200, "start": "nova", "light": 118.0, "speed": 0.88, "radius": 1.15},
	{"id": "comet", "name": "Comet", "blurb": "Burns everything behind it. Starts with Ember Trail.",
	 "outer": Color(0.28, 0.60, 1.0), "inner": Color(0.75, 0.92, 1.0), "cost": 320, "start": "trail", "light": 100.0, "speed": 1.1, "radius": 1.0},
]


static func flame(id: String) -> Dictionary:
	for f in FLAMES:
		if f.id == id: return f
	return FLAMES[0]


const SHOP := [
	{"id": "flame", "icon": "soul", "name": "Thicker Wick", "blurb": "+8 max light every run", "max": 5, "cost": 30},
	{"id": "power", "icon": "sharp", "name": "Hotter Sparks", "blurb": "+6% damage every run", "max": 5, "cost": 40},
	{"id": "feet", "icon": "feet", "name": "Light Steps", "blurb": "+4% move speed every run", "max": 5, "cost": 30},
	{"id": "wisdom", "icon": "wisdom", "name": "Old Stories", "blurb": "+8% XP every run", "max": 5, "cost": 40},
	{"id": "reroll", "icon": "reroll", "name": "Lucky Dice", "blurb": "+1 card reroll per run", "max": 3, "cost": 60},
	{"id": "choice", "icon": "choice", "name": "Fourth Card", "blurb": "Choose from 4 upgrades, not 3", "max": 1, "cost": 300},
]

const NO_MODIFIER := {"name": "", "blurb": "", "bat": 0.0, "drain": 1.0, "xp": 1.0, "espeed": 1.0, "spawn": 1.0, "radius": 1.0, "hp": 1.0, "dust": 1.0}
const DAILY := [
	{"name": "Bat Night", "blurb": "The sky is full of bats. Double stardust.", "bat": 0.5, "drain": 1.0, "xp": 1.0, "espeed": 1.0, "spawn": 1.0, "radius": 1.0, "hp": 1.0, "dust": 2.0},
	{"name": "Thin Air", "blurb": "Your light burns faster, but embers are richer.", "bat": 0.0, "drain": 1.7, "xp": 1.3, "espeed": 1.0, "spawn": 1.0, "radius": 1.0, "hp": 1.0, "dust": 2.0},
	{"name": "Hasty Shadows", "blurb": "Everything moves faster. Extra stardust.", "bat": 0.0, "drain": 1.0, "xp": 1.0, "espeed": 1.2, "spawn": 1.0, "radius": 1.0, "hp": 1.0, "dust": 2.0},
	{"name": "Crowded", "blurb": "Far more shadows, and far more embers.", "bat": 0.0, "drain": 1.0, "xp": 1.1, "espeed": 1.0, "spawn": 1.45, "radius": 1.0, "hp": 1.0, "dust": 2.0},
	{"name": "Full Moon", "blurb": "You can see far, but shadows are tougher.", "bat": 0.0, "drain": 1.0, "xp": 1.0, "espeed": 1.0, "spawn": 1.0, "radius": 1.45, "hp": 1.35, "dust": 2.0},
]


static func day_number() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


static func today() -> Dictionary:
	return DAILY[day_number() % DAILY.size()]


static func time_string(seconds: float) -> String:
	var s := maxi(0, ceili(seconds))
	return "%d:%02d" % [s / 60, s % 60]
