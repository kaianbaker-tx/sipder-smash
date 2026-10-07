class_name Suits
## Every spider suit, in the order of the dimensions you beat to unlock them.
## Made by tools/gen_suits.py: edit that, then re-run it.
## dim = the dimension to beat ("" = always yours). perk = the suit's power.

const LIST := {
	"classic": {"name": "CLASSIC", "tex": "res://assets/hero/suits/classic.png", "dim": "", "perk": "regen", "desc": "The one and only!"},
	"noir": {"name": "NOIR", "tex": "res://assets/hero/suits/noir.png", "dim": "NOIR-VERSE", "perk": "power", "desc": "Black & white world!"},
	"candy": {"name": "CANDY", "tex": "res://assets/hero/suits/candy.png", "dim": "CANDY-VERSE", "perk": "points", "desc": "Sweet stripes, like a candy cane."},
	"lava": {"name": "LAVA", "tex": "res://assets/hero/suits/lava.png", "dim": "LAVA-VERSE", "perk": "power", "desc": "Too hot to handle!"},
	"jungle": {"name": "JUNGLE", "tex": "res://assets/hero/suits/jungle.png", "dim": "JUNGLE-VERSE", "perk": "stealth", "desc": "Hide in the leaves."},
	"ice": {"name": "ICE", "tex": "res://assets/hero/suits/ice.png", "dim": "ICE-VERSE", "perk": "speed", "desc": "Slippery and super cool."},
	"desert": {"name": "DESERT", "tex": "res://assets/hero/suits/desert.png", "dim": "DESERT-VERSE", "perk": "regen", "desc": "Sandy, sunny and tough."},
	"toy": {"name": "TOY", "tex": "res://assets/hero/suits/toy.png", "dim": "TOY-VERSE", "perk": "points", "desc": "Bright like a brand-new toy."},
	"moon": {"name": "MOON", "tex": "res://assets/hero/suits/moon.png", "dim": "MOON-VERSE", "perk": "float", "desc": "Made for low gravity."},
	"pixel": {"name": "PIXEL", "tex": "res://assets/hero/suits/pixel.png", "dim": "PIXEL-VERSE", "perk": "jump", "desc": "8-bit hero, 100% cool."},
	"ghost": {"name": "GHOST", "tex": "res://assets/hero/suits/ghost.png", "dim": "SPOOKY-VERSE", "perk": "speed", "desc": "Hood up. Spooky and quick."},
	"neon": {"name": "NEON", "tex": "res://assets/hero/suits/neon.png", "dim": "NEON-VERSE", "perk": "speed", "desc": "Glows in the dark city."},
	"cloud": {"name": "CLOUD", "tex": "res://assets/hero/suits/cloud.png", "dim": "CLOUD-VERSE", "perk": "float", "desc": "Light and fluffy."},
	"temple": {"name": "TEMPLE", "tex": "res://assets/hero/suits/temple.png", "dim": "TEMPLE-VERSE", "perk": "regen", "desc": "Ancient marble and gold."},
	"mushroom": {"name": "MUSHROOM", "tex": "res://assets/hero/suits/mushroom.png", "dim": "MUSHROOM-VERSE", "perk": "jump", "desc": "Spotty and bouncy."},
	"factory": {"name": "FACTORY", "tex": "res://assets/hero/suits/factory.png", "dim": "FACTORY-VERSE", "perk": "power", "desc": "Heavy-duty robot smasher."},
	"beach": {"name": "BEACH", "tex": "res://assets/hero/suits/beach.png", "dim": "BEACH-VERSE", "perk": "regen", "desc": "Surf's up, bots down!"},
	"space": {"name": "SPACE", "tex": "res://assets/hero/suits/space.png", "dim": "SPACE-VERSE", "perk": "float", "desc": "A suit full of stars."},
	"autumn": {"name": "AUTUMN", "tex": "res://assets/hero/suits/autumn.png", "dim": "AUTUMN-VERSE", "perk": "stealth", "desc": "Crunchy leaf camo."},
	"crystal": {"name": "CRYSTAL", "tex": "res://assets/hero/suits/crystal.png", "dim": "CRYSTAL-VERSE", "perk": "points", "desc": "Sparkly purple crystals."},
	"cheese": {"name": "CHEESE", "tex": "res://assets/hero/suits/cheese.png", "dim": "CHEESE-VERSE", "perk": "regen", "desc": "Cheesy... but powerful!"},
	"winter": {"name": "WINTER", "tex": "res://assets/hero/suits/winter.png", "dim": "WINTER-VERSE", "perk": "regen", "desc": "Warm, cosy and festive."},
	"brick": {"name": "BRICK", "tex": "res://assets/hero/suits/brick.png", "dim": "BRICK-VERSE", "perk": "jump", "desc": "Built like a brick wall."},
	"storm": {"name": "STORM", "tex": "res://assets/hero/suits/storm.png", "dim": "STORM-VERSE", "perk": "speed", "desc": "Fast as lightning."},
	"swamp": {"name": "SWAMP", "tex": "res://assets/hero/suits/swamp.png", "dim": "SWAMP-VERSE", "perk": "stealth", "desc": "Slimy and sneaky."},
	"retro": {"name": "RETRO", "tex": "res://assets/hero/suits/retro.png", "dim": "RETRO-VERSE", "perk": "speed", "desc": "Totally radical, dude!"},
	"party": {"name": "PARTY", "tex": "res://assets/hero/suits/party.png", "dim": "PARTY-VERSE", "perk": "points", "desc": "Confetti for everyone!"},
	"maze": {"name": "MAZE", "tex": "res://assets/hero/suits/maze.png", "dim": "MAZE-VERSE", "perk": "stealth", "desc": "You'll never find me."},
	"farm": {"name": "FARM", "tex": "res://assets/hero/suits/farm.png", "dim": "FARM-VERSE", "perk": "regen", "desc": "Overalls and a plaid shirt."},
	"shadow": {"name": "SHADOW", "tex": "res://assets/hero/suits/shadow.png", "dim": "SHADOW-VERSE", "perk": "stealth", "desc": "Only your eyes glow."},
	"ruins": {"name": "RUINS", "tex": "res://assets/hero/suits/ruins.png", "dim": "RUINS-VERSE", "perk": "power", "desc": "Old stones, new hero."},
	"underwater": {"name": "UNDERWATER", "tex": "res://assets/hero/suits/underwater.png", "dim": "UNDERWATER-VERSE", "perk": "float", "desc": "Blub blub! Bubbles!"},
	"mars": {"name": "MARS", "tex": "res://assets/hero/suits/mars.png", "dim": "MARS-VERSE", "perk": "jump", "desc": "Red planet power."},
	"jelly": {"name": "JELLY", "tex": "res://assets/hero/suits/jelly.png", "dim": "JELLY-VERSE", "perk": "jump", "desc": "Wobbly and bouncy."},
	"blueprint": {"name": "BLUEPRINT", "tex": "res://assets/hero/suits/blueprint.png", "dim": "BLUEPRINT-VERSE", "perk": "points", "desc": "Drawn by a genius."},
	"pencil": {"name": "PENCIL", "tex": "res://assets/hero/suits/pencil.png", "dim": "PENCIL-VERSE", "perk": "stealth", "desc": "A walking sketch."},
	"chess": {"name": "CHESS", "tex": "res://assets/hero/suits/chess.png", "dim": "CHESS-VERSE", "perk": "power", "desc": "Checkmate, bots!"},
	"camp": {"name": "CAMP", "tex": "res://assets/hero/suits/camp.png", "dim": "CAMP-VERSE", "perk": "regen", "desc": "Ready for a night outdoors."},
	"gold": {"name": "GOLDEN", "tex": "res://assets/hero/suits/gold.png", "dim": "GOLDEN-VERSE", "perk": "points", "desc": "Shiny! (Or find 25 tokens.)"},
	"spiral": {"name": "SPIRAL", "tex": "res://assets/hero/suits/spiral.png", "dim": "SPIRAL-VERSE", "perk": "speed", "desc": "Round and round we go!"},
	"slime": {"name": "SLIME", "tex": "res://assets/hero/suits/slime.png", "dim": "SLIME-VERSE", "perk": "regen", "desc": "Gooey green power."},
	"upside": {"name": "UPSIDE-DOWN", "tex": "res://assets/hero/suits/upside.png", "dim": "UPSIDE-DOWN-VERSE", "perk": "jump", "desc": "The classic suit, flipped!"},
	"rainbow": {"name": "RAINBOW", "tex": "res://assets/hero/suits/rainbow.png", "dim": "RAINBOW-VERSE", "perk": "points", "desc": "Every colour at once!"},
	"blossom": {"name": "BLOSSOM", "tex": "res://assets/hero/suits/blossom.png", "dim": "BLOSSOM-VERSE", "perk": "regen", "desc": "Pretty in pink petals."},
	"electric": {"name": "ELECTRIC", "tex": "res://assets/hero/suits/electric.png", "dim": "ELECTRIC-VERSE", "perk": "speed", "desc": "ZAP! Super charged."},
	"sunset": {"name": "SUNSET", "tex": "res://assets/hero/suits/sunset.png", "dim": "SUNSET-VERSE", "perk": "power", "desc": "Orange, pink and purple."},
	"midnight": {"name": "MIDNIGHT", "tex": "res://assets/hero/suits/midnight.png", "dim": "MIDNIGHT-VERSE", "perk": "stealth", "desc": "Dark as midnight."},
	"saturn": {"name": "SATURN", "tex": "res://assets/hero/suits/saturn.png", "dim": "SATURN-VERSE", "perk": "float", "desc": "Rings around a hero."},
	"mega": {"name": "MEGA", "tex": "res://assets/hero/suits/mega.png", "dim": "MEGA-VERSE", "perk": "power", "desc": "Big hero energy."},
	"speed": {"name": "SPEED", "tex": "res://assets/hero/suits/speed.png", "dim": "SPEED-VERSE", "perk": "speed", "desc": "Zoom zoom zoom!"},
	"domino": {"name": "DOMINO", "tex": "res://assets/hero/suits/domino.png", "dim": "DOMINO-VERSE", "perk": "points", "desc": "Black and white dots."},
	"nightmare": {"name": "NIGHTMARE", "tex": "res://assets/hero/suits/nightmare.png", "dim": "NIGHTMARE-VERSE", "perk": "power", "desc": "Scary red eyes."},
	"web": {"name": "WEB", "tex": "res://assets/hero/suits/web.png", "dim": "WEB-VERSE", "perk": "speed", "desc": "From the home of all spiders."},
	"glitch": {"name": "GLITCH", "tex": "res://assets/hero/suits/glitch.png", "dim": "GLITCH-VERSE", "perk": "all", "desc": "Beat the Glitch King to earn it."},
}

const PERKS := {
	"regen": "Heals faster!",
	"stealth": "Bots spot you later!",
	"speed": "Swings super fast!",
	"power": "Hits harder!",
	"points": "DOUBLE POINTS!",
	"float": "Floaty moon jumps!",
	"jump": "Jumps extra high!",
	"all": "Has EVERY power!",
}


## The suit you win in a dimension (by its name, like "LAVA-VERSE").
static func for_dim(dim_name: String) -> String:
	for k in LIST:
		if LIST[k].dim == dim_name:
			return k
	return ""
