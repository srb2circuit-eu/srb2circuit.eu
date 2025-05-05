//lagkiller 2000
//product of katsy

local MF_NOTHINK = MF_NOTHINK
local MF_NOBLOCKMAP = MF_NOBLOCKMAP
local TICRATE = TICRATE
local FRACBITS = FRACBITS
local MF_BOSS = MF_BOSS

local fusemobjs = {}

fusemobjs[MT_LAVAFALL] = true
fusemobjs[MT_FLAMEJET] = true
fusemobjs[MT_VERTICALFLAMEJET] = true
fusemobjs[MT_BLUEFLAG] = true
fusemobjs[MT_REDFLAG] = true

local dist = 2000<<FRACBITS

addHook("MapThingSpawn", function(mobj)
	if (mapheaderinfo[gamemap].lvlttl == "Hub") return nil end
	if not (mobj.player) and not (mobj.flags & MF_BOSS) and not fusemobjs[mobj]
		mobj.flags = $|MF_NOTHINK & ~MF_NOBLOCKMAP
		mobj.spawnfrozen = true
	end
end)

local function telescan(fang, tree)
	if (tree.spawnfrozen)
		tree.flags = $ & ~MF_NOTHINK
		tree.spawnfrozen = false
		tree.fuse = TICRATE<<2
	end
end

addHook("PlayerThink", function(player)
	if not (player.mo) return end
	if (player.mo.bot) return end
	searchBlockmap("objects", telescan, player.mo, player.mo.x-dist, player.mo.x+dist, player.mo.y-dist, player.mo.y+dist)
end)

addHook("MobjFuse", function(mobj)
	if (mobj.spawnfrozen == false)
		mobj.flags = $|MF_NOTHINK
		mobj.spawnfrozen = true
		return true
	end
end)