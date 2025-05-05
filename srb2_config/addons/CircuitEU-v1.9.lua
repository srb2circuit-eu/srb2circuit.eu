--[[ --MapVote - Created by Krabs
--6 map level vote by LeonardoTheMutant

local score_time = CV_RegisterVar({
	name = "scoretime",
	defaultvalue = tostring(11),
	flags = CV_NETVAR,
	PossibleValue = {MIN = 1, MAX = 100}
})
local vote_time = CV_RegisterVar({
	name = "votetime",
	defaultvalue = tostring(13),
	flags = CV_NETVAR,
	PossibleValue = {MIN = 1, MAX = 100}
})
--local weighted_random = CV_RegisterVar({
--    name = "weightedrandom",
--    defaultvalue = "On",
--    flags = CV_NETVAR,
--    PossibleValue = CV_OnOff
--})
--local base_weight = CV_RegisterVar({
--    name = "baseweight",
--	defaultvalue = "0",
--	flags = CV_NETVAR,
--	PossibleValue = {MIN = 0, MAX = 2}
--})
--local vote_weight = CV_RegisterVar({
--    name = "voteweight",
--	defaultvalue = tostring(1),
--	flags = CV_NETVAR,
--	PossibleValue = CV_Natural
--})
local skip_music = CV_RegisterVar({
    name = "skipmusic",
    defaultvalue = "On",
    flags = CV_NETVAR,
    PossibleValue = CV_OnOff
})
local oldc_mode = CV_RegisterVar({
    name = "oldcmode",
    defaultvalue = "Off",
    flags = CV_NETVAR,
    PossibleValue = CV_OnOff
})

--Constants
local END_TIME = 6
local VSND_SELECT = sfx_s240
local VSND_CONFIRM = sfx_s3k63
local VSND_VOTE_START = sfx_s243
local VSND_CANCEL = sfx_s3k72
local VSND_MISSED_VOTE = sfx_s3k74
local VSND_SPEEDING_OFF = sfx_lvpass
local VSND_BEEP = sfx_s3k89
local IPH_NONE = 0
local IPH_SCORE = 1
local IPH_VOTE = 2
local IPH_END = 3
local IPH_STOP = 4
--]]

--Initialize gametype constants
local GAMETYPE_AMT_VANILLA = 7

--[[
--Netvars
rawset(_G, "netvote",{})
netvote.score_timeleft = score_time.value * TICRATE - 1
netvote.vote_timeleft = vote_time.value * TICRATE - 1
netvote.end_timeleft = END_TIME * TICRATE - 1
netvote.enabled_gametypes = {2}
netvote.map_whitelist = {}
netvote.map_blacklist = {}
netvote.maplist = {}
netvote.mapbag = {}
netvote.phase = IPH_NONE
netvote.map_choice = {}
netvote.gt_choice = {}
netvote.vote_tally = {}
netvote.bestslots = {}
netvote.decided_map = 1
netvote.decided_gt = GT_RACE
netvote.charruntime = 0
netvote.runskin = 0

addHook("NetVars", function(n)
	netvote = n($)
end)

--Reset vars on map load
addHook("MapLoad", function()
	hud.enable("intermissiontally")
	netvote.phase = IPH_NONE
	netvote.map_choice = {1,2,3,4,5,6}
	netvote.gt_choice = {0,1,2}
	netvote.vote_tally = {0,0,0,0,0,0}
	netvote.bestslots = {}
	netvote.decided_map = 1
	netvote.decided_gt = GT_RACE
	netvote.charruntime = 0
	netvote.runskin = 0
end)
]]

--table_contains_value(t,v)
--Returns true if t contains c
local function table_contains_value(t,v)
	for i = 0, #t
		if v == t[i] return true end
	end
	return false
end

--[[
local function MapGetAuthor(m)
	if (m == nil)
		return "ERROR: nil mapnum"
	end
	local h = mapheaderinfo[m]
	if (h)
		if (h.author) return " by " + h.author end
	end
	return ""
end

local function OLDCGetNext(m)
	if (m == nil) return "ERROR: nil mapnum" end

	local nxt = m + 1
	local tries = 0
	while(mapheaderinfo[nxt] == nil and tries < 3)
		tries = $ + 1
		if (nxt >= 100 and nxt <= 135)
			nxt = 148 --bc
		elseif (nxt >= 148 and nxt <= 171)
			nxt = 172 --c0
		elseif (nxt >= 172 and nxt <= 207)
			nxt = 100 --a0
		end
	end

	return nxt
end

--ScanMaps()
--Put all maps into the table
--Searches through all maps with a level header and adds them to netvote.maplist
local function ScanMaps()
	netvote.maplist = {}
	for m = 1, #mapheaderinfo
		local wl = netvote.map_whitelist
		local val = false

		if table_contains_value(wl, m)
			--print("Map "..m)
			val = true
		end

		if (not #wl) val = true end

		if table_contains_value(netvote.map_blacklist ,m) val = false end

		if (mapheaderinfo[m] and val == true)
			--print("Found map: " + m + " - " + G_BuildMapName(m) + " - " + G_BuildMapTitle(m))
			table.insert(netvote.maplist, m)
		end
	end
end
]]

--JJK
--char_to_num(char)
--Converts character to int
local char_to_num = function(char)
    return string.byte(char)-string.byte("A")
end

--JJK
--ExtMapNumToInt(ext)
--Returns the mapnum int
--Returns nil if it's invalid
local function ExtMapNumToInt(ext)
	ext = ext:upper()
	if ext:sub(1, 3) == "MAP" then
		ext = ext:sub(4,5)
		--print("removing MAP chars")
	end

    local num = tonumber(ext)
    if (num != nil) then
		--print("simple number")
        return num
    end

	if ext:len() != 2 then
		--print("mapnum too long")
		return nil
	end

    local x = ext:sub(1,1)
	if tonumber(x) then
		--print("first digit is a number when it shouldn't be")
		return nil
	end

	--print("valid ext mapnum")
    local y = ext:sub(2,2)
    local p = char_to_num(x)
    local q = tonumber(y)

    if (q == nil) then q = 10 + char_to_num(y) end

    return ((36*p + q) + 100)
end

--IntToGametypeName(g)
--Returns a string name
--Returns " " if the gametype is invalid
local function IntToGametypeName(g)
	local gtnames = {
		[GT_COOP] = "Co-op",
		[GT_COMPETITION] = "Competition",
		[GT_RACE] = "Race",
		[GT_MATCH] = "Match",
		[GT_TEAMMATCH] = "Team Match",
		[GT_TAG] = "Tag",
		[GT_HIDEANDSEEK] = "Hide & Seek",
		[GT_CTF] = "CTF"
	}
	return gtnames[g]
end

--[[
COM_AddCommand("gametypelist", function(p, ...)
	local gt = {...}
	if ((gt == nil) or (#gt == 0)) print("Please supply a list of gametype numbers, separated by spaces.") end

	local egt = {}

	for i = 1, #gt
		local gametype = tonumber(gt[i])
		if gametype == nil
			print("Invalid gametype. Must be numeric.")
			return
		end
		if IntToGametypeName(gametype) == nil
			print("Invalid gametype: " + gametype)
			return
		end
		table.insert(egt, gametype)
		print("Added gametype: " + IntToGametypeName(gametype))
	end

	netvote.enabled_gametypes = egt
end, COM_ADMIN)

COM_AddCommand("mapwhitelist", function(p, ...)
	local wl = {...}
	if ((wl == nil) or (#wl == 0))
		print("Please supply a list of whitelisted maps, using extended map numbers. Cleared the list.")
		netvote.map_whitelist = {}
	end

	local whitelist = {}

	for i = 1, #wl
		--if wl[i] == nil        -- how is this even true???
		--	print("nil mapnum.")
		--	return
		--end
		local mapnum = ExtMapNumToInt(wl[i])
		if mapnum == nil
			print("Invalid map: " + wl[i])
			return
		end
		table.insert(whitelist, mapnum)
		print("whitelisted map: " + mapnum)
	end

	netvote.map_whitelist = whitelist
end, COM_ADMIN)

COM_AddCommand("mapblacklist", function(p, ...)
	local bl = {...}
	if bl == nil or #bl == 0
		print("Please supply a list of blacklisted maps, using extended map numbers. Cleared the list.")
		netvote.map_blacklist = {}
	end

	local blacklist = {}

	for i = 1, #bl
		--if bl[i] == nil         -- how is this even true???
		--	print("nil mapnum.")
		--	return
		--end
		local mapnum = ExtMapNumToInt(bl[i])
		if mapnum == nil
			print("Invalid map: " + bl[i])
			return
		end
		table.insert(blacklist, mapnum)
		print("blacklisted map: " + mapnum)
	end

	netvote.map_blacklist = blacklist
end, COM_ADMIN)

--MapAvailableGametypes(m)
--Returns a table containing all gametype IDs that the map supports.
local function MapAvailableGametypes(m)
	local h = mapheaderinfo[m]
	if (not h)
		print("ERROR: map "+ G_BuildMapTitle(m) +" has no header.")
		return nil
	end

	local gt = {}

	local tol_table = {
		[GT_COOP] = TOL_COOP,
		[GT_COMPETITION] = TOL_COMPETITION,
		[GT_RACE] = TOL_RACE,
		[GT_MATCH] = TOL_MATCH,
		[GT_TEAMMATCH] = TOL_MATCH,
		[GT_TAG] = TOL_TAG,
		[GT_HIDEANDSEEK] = TOL_TAG,
		[GT_CTF] = TOL_CTF
	}

	for i = GT_COOP,GAMETYPE_AMT_VANILLA
		if table_contains_value(netvote.enabled_gametypes, i)
			if (h.typeoflevel & tol_table[i]) table.insert(gt, i) end
		end
	end

	if (not #gt) return end

	return gt
end


--GetRandomMaps()
--Returns a table with three random maps, and removes those maps from netvote.mapbag
local function GetRandomMaps()
	ScanMaps()
	netvote.mapbag = {}
	for i = 1, #netvote.maplist
		if MapAvailableGametypes(netvote.maplist[i])
			table.insert(netvote.mapbag, netvote.maplist[i])
		end
	end

	if #netvote.mapbag < 6
		print("Error - not enough maps")
		return {1,1,1}
	end

	local m = {}
	local index
	for i = 1,6 do
		index = P_RandomKey(#netvote.mapbag) + 1
		m[i] = netvote.mapbag[index]
		table.remove(netvote.mapbag, index)
	end
	return m
end

--GetARandomGametype(m)
--Returns a random gametype ID that is compatible with map m
local function GetARandomGametype(m)
	local gtypes = MapAvailableGametypes(m)
	return gtypes[P_RandomKey(#gtypes) + 1]
end

--GetRandomGametypes(m)
--m must be a table with three map IDs in it.
--Returns a table containing 6 random gametypes that correspond with the six maps in table m
local function GetRandomGametypes(m)
	local g = {}
	for i = 1,6 do
		g[i] = GetARandomGametype(m[i])
	end
	return g
end

local function PicPos2MapIndex(x, y)
	--I know, this is stupid
	if (x == 0) and (y == 0) return 1
	elseif (x == 1) and (y == 0) return 2
	elseif (x == 2) and (y == 0) return 3
	elseif (x == 0) and (y == 1) return 4
	elseif (x == 1) and (y == 1) return 5
	elseif (x == 2) and (y == 1) return 6
	else return 1 end
end

--Intermission countdown and voting
addHook("IntermissionThinker", function()
	--Disable vanilla intermission timer text
	if (hud.enabled("intermissionmessages")) hud.disable("intermissionmessages") end

	--Switch to the score phase
	if netvote.phase == IPH_NONE
		netvote.map_choice = GetRandomMaps()
		netvote.gt_choice = GetRandomGametypes(netvote.map_choice)
		netvote.phase = IPH_SCORE
		netvote.score_timeleft = score_time.value * TICRATE - 1
		netvote.vote_timeleft = vote_time.value * TICRATE - 1
		netvote.end_timeleft = END_TIME * TICRATE - 1
		for p in players.iterate do
			p.vote_slot = 1
			p.vote_x = 0
			p.vote_y = 0
			p.voted = false
		end

	--Score
	elseif netvote.phase == IPH_SCORE
		--Enable the score
		if (not hud.enabled("intermissiontally")) hud.enable("intermissiontally") end
		--Timer
		if (netvote.score_timeleft > 0)
			netvote.score_timeleft = $ - 1
		--Switch to the voting phase
		else
			if (oldc_mode.value) --Voting is disabled in oldc mode. Just go to the next valid map in the A, B, or C mapnums
				netvote.phase = IPH_END
				S_StartSound(nil, VSND_SPEEDING_OFF, nil)
				netvote.charruntime = 0
				local skinlist = {"sonic", "tails", "knuckles", "amy", "fang", "metalsonic"}
				netvote.runskin = skinlist[P_RandomKey(#skinlist) + 1]

				--No voting allowed idiots, this is OLDC
				netvote.decided_map = OLDCGetNext(gamemap)
				netvote.decided_gt = GetARandomGametype(netvote.decided_map)
				print("\130Next map is: " + G_BuildMapTitle(netvote.decided_map) + " " + MapGetAuthor(netvote.decided_map))
			else
				netvote.phase = IPH_VOTE
				S_StartSound(nil, VSND_VOTE_START, nil)
			end

			if (skip_music.value) S_SetMusicPosition(35000) end
		end

	--Voting
	elseif netvote.phase == IPH_VOTE
		--Disable the score
		if (hud.enabled("intermissiontally")) hud.disable("intermissiontally") end
		--Time to vote
		if (netvote.vote_timeleft > 0)
			netvote.vote_timeleft = $ - 1

			--Reset vote counter each frame
			netvote.vote_tally = {0,0,0,0,0,0}

			--Voting controls
			for player in players.iterate
				if (not player.vote_slot)
					player.vote_slot = 1
					player.vote_x = 0
					player.vote_y = 0
					player.voted = false
				else
					--Input checking
					local btn = player.cmd.buttons
					local pbtn = player.prevbuttons
					if (pbtn == nil) pbtn = btn end

					local up = (player.cmd.forwardmove >= 10)
					local down = (player.cmd.forwardmove <= -10)
					local left = (player.cmd.sidemove <= -10)
					local right = (player.cmd.sidemove >= 10)
					local pup = player.prevup
					local pdown = player.prevdown
					local pleft = player.prevleft
					local pright = player.prevright

					local confirm =	((btn & BT_JUMP) and not (pbtn & BT_JUMP)) or ((btn & BT_ATTACK) and not (pbtn & BT_ATTACK))
					local cancel = (btn & BT_SPIN) and not (pbtn & BT_SPIN)
					local scrollup = up and not pup
					local scrolldown = down and not pdown
					local scrollleft = left and not pleft
					local scrollright = right and not pright

					if (not player.voted)
						--Select a map with up and down
						if (scrollup or scrolldown or scrollleft or scrollright)
							S_StartSound(nil, VSND_SELECT, player)

							if (scrollup)
								player.vote_y = $ - 1
								if (player.vote_y < 0) player.vote_y = 1 end
							elseif (scrolldown)
								player.vote_y = $ + 1
								if (player.vote_y > 1) player.vote_y = 0 end
							elseif (scrollleft)
								player.vote_x = $ - 1
								if (player.vote_x < 0) player.vote_x = 2 end
							elseif (scrollright)
								player.vote_x = $ + 1
								if (player.vote_x > 2) player.vote_x = 0 end
							end
						end

						player.vote_slot = PicPos2MapIndex(player.vote_x, player.vote_y)

						--Confirm the selection with jump or attack button
						if (confirm)
							S_StartSound(nil, VSND_CONFIRM, player)
							player.voted = true
						end
					end
					if (cancel)
						S_StartSound(nil, VSND_CANCEL, player)
						player.voted = false
					end

					--Previous frame inputs
					player.prevbuttons = btn
					player.prevup = up
					player.prevdown = down
					player.prevleft = left
					player.prevright = right


					if ((netvote.vote_timeleft == 0) and (not player.voted)) S_StartSound(nil, VSND_MISSED_VOTE, player) end
				end

				--Increase the vote tally if it's been selected or if time ran out
				if (player.voted) netvote.vote_tally[player.vote_slot] = $ + 1 end
			end
			--Countdown beeps for the last 3 seconds of voting
			if ((netvote.vote_timeleft > 0) and (netvote.vote_timeleft <= 105) and (netvote.vote_timeleft % TICRATE == 0)) S_StartSound(nil, VSND_BEEP) end
		else
			netvote.phase = IPH_END
			S_StartSound(nil, VSND_SPEEDING_OFF, nil)
			netvote.charruntime = 0
			local skinlist = {"sonic", "tails", "knuckles", "amy", "fang", "metalsonic"}
			netvote.runskin = skinlist[P_RandomKey(#skinlist) + 1]

			--Choose the most popular map or roll an RNG tiebreaker.
			local votedslot

			--Get the best number of tallies
			local best = 0
			for slot = 1, 6 do
				if (netvote.vote_tally[slot] > best) best = netvote.vote_tally[slot] end
			end
			--How many tied slots are there with the top number?
			for slot = 1, 6 do
				if (netvote.vote_tally[slot] == best) table.insert(netvote.bestslots, slot) end
			end
			--Now select the random slot among best slots
			votedslot = netvote.bestslots[P_RandomKey(#netvote.bestslots) + 1]

			--ORIGINAL CODE

			--local votedslot = 1
            --if (weighted_random.value)
            --    local num_votes = 0
            --    for i = 1,3 do
            --        netvote.vote_tally[i] = $ * vote_weight.value + base_weight.value
            --        num_votes = $ + netvote.vote_tally[i]
            --    end
			--
			--	if (num_votes == 0) votedslot = P_RandomRange(1,3)
			--	else
			--		local weight_select = P_RandomKey(num_votes) + 1
			--		--print(num_votes)
			--		--print(weight_select)
			--		local vote_count = 0
			--		for i = 1,3 do
			--			local current_tally = netvote.vote_tally[i]
			--			--print(vote_count + current_tally)
			--			if (weight_select <= vote_count + current_tally)
			--				votedslot = i
			--				break
			--			else vote_count = $ + current_tally end
			--		end
			--	end
            --else
            --  --Choose the most popular map or roll an RNG tiebreaker. This is probably a dumb way to do this but shut up
			--	if netvote.vote_tally[1] == netvote.vote_tally[2] and netvote.vote_tally[1] == netvote.vote_tally[3] --three way tiebreaker
			--		votedslot = P_RandomRange(1,3)
			--		print("\130There's a three-way tie! Picking randomly...")
			--	elseif netvote.vote_tally[1] == netvote.vote_tally[2] and netvote.vote_tally[3] < netvote.vote_tally[1] --two way tiebreaker, slot 1 or 2
			--		votedslot = P_RandomRange(1,2)
			--		print("\130There's a two-way tie! Picking randomly...")
			--	elseif netvote.vote_tally[2] == netvote.vote_tally[3] and netvote.vote_tally[1] < netvote.vote_tally[2] --two way tiebreaker, slot 2 or 3
			--		votedslot = P_RandomRange(2,3)
			--		print("\130There's a two-way tie! Picking randomly...")
			--	elseif netvote.vote_tally[1] == netvote.vote_tally[3] and netvote.vote_tally[2] < netvote.vote_tally[1] --two way tiebreaker, slot 1 or 3
			--		if P_RandomRange(1,2) == 1
			--			votedslot = 1
			--		else
			--			votedslot = 3
			--		end
			--		print("\130There's a two-way tie! Picking randomly...")
			--	else
			--		local best = 0
			--		for i = 1, 3
			--			if netvote.vote_tally[i] > best
			--				best = netvote.vote_tally[i]
			--				votedslot = i
			--			end
			--		end
			--	end
            --end

			netvote.decided_map = netvote.map_choice[votedslot]
			netvote.decided_gt = netvote.gt_choice[votedslot]
			print("\x82The winner is: " + G_BuildMapTitle(netvote.decided_map) + MapGetAuthor(netvote.decided_map))
		end

	--End
	elseif netvote.phase == IPH_END
		--Disable the score
		if (hud.enabled("intermissiontally")) hud.disable("intermissiontally") end
		--Timer
		netvote.charruntime = $ + 1
		if (netvote.end_timeleft > 0)
			netvote.end_timeleft = $ - 1
		--Change the map
		else
			local gotomap = G_BuildMapName(netvote.decided_map)
			netvote.phase = IPH_STOP
			COM_BufInsertText(server, "map " + gotomap + " -gt " + netvote.decided_gt + " -f")
		end
	end
end)

addHook("PlayerThink", function(player)
	--Keep track of the skin each player was last using before intermission
	if (player.realmo) player.lastknownskin = player.realmo.skin end
end)

--Intermission voting HUD display
hud.add(function(v, player)
	local player = consoleplayer
	if netvote.phase == IPH_NONE return end

	--Thumbnail pictures of the 6 choices
	local vote_pic = {}
	for i = 1, 6
		local pname = G_BuildMapName(netvote.map_choice[i]) + "P"
		if v.patchExists(pname) vote_pic[i] = v.cachePatch(pname)
		else vote_pic[i] = v.cachePatch("BLANKLVL") end
	end

	--Display stuff based on the current intermission phase
	if netvote.phase == IPH_SCORE
		local vbtext = "Vote begins in "
		if (oldc_mode.value) vbtext = "Next map in " end

		v.drawString(160, 170, vbtext + (netvote.score_timeleft / TICRATE) + " seconds", V_ALLOWLOWERCASE | V_SNAPTOBOTTOM | V_YELLOWMAP, "center")

	elseif netvote.phase == IPH_VOTE
		v.drawString(160, 8, "*VOTING*", V_SNAPTOTOP, "center")
		v.drawString(160, 170, "Vote ends in " + (netvote.vote_timeleft / TICRATE) + " seconds", V_ALLOWLOWERCASE | V_SNAPTOBOTTOM | V_YELLOWMAP, "center")
		v.drawString(160, 180, "Select: JUMP     Cancel: SPIN", V_ALLOWLOWERCASE | V_SNAPTOBOTTOM, "small-center")

		--Draw the map choices and vote amounts
		local map
		--Map pictures
		local picscale = 32768 --FRACUNIT/2
		local startX = 24 --X of the first picture
		local startY = 24 --Y of the first picture
		local xoffset = 96
		local yoffset = 72
		local mapn
		local pic
		local cmap1 = v.getColormap(TC_RAINBOW, SKINCOLOR_JET)
		local cmap2 = v.getColormap(TC_DEFAULT)
		local cmap
		local tflags1 = V_ALLOWLOWERCASE | V_SNAPTOLEFT
		local tflags2 = V_ALLOWLOWERCASE | V_SNAPTOLEFT | V_YELLOWMAP
		local tflags

		--Player heads
		local headxoff = 8
		local headyoff = 16
		local headStartXoffset = 0
		local headStartYoffset = 64
		local headX, headY
		local amountheads

		for y = 0, 1 do
			for x = 0, 2 do
				--Map pictures
				map = PicPos2MapIndex(x,y)
				mapn = G_BuildMapTitle(netvote.map_choice[map])
				pic = vote_pic[map]

				if (player.vote_slot == map)
					cmap = cmap2
					tflags = tflags2
					v.drawScaled((startX + (x*xoffset))*FU, (startY + (y*yoffset))*FU, picscale, v.cachePatch("SLCT1LVL"), V_SNAPTOLEFT)
				else
					cmap = cmap1
					tflags = tflags1
				end

				--map picture
				v.drawScaled((startX + (x*xoffset))*FU, (startY + (y*yoffset))*FU, picscale, pic, V_SNAPTOLEFT, cmap)

				--text
				if (v.stringWidth(mapn, tlags, "thin") >= 72) mapn = mapn:sub(0, 14).."..." end --Map name might be too long to fit
				v.drawString((startX + (x*xoffset) + 2), (startY + (y*yoffset) + 2), mapn, tflags, "thin")
				v.drawString((startX + (x*xoffset) + 2), (startY + (y*yoffset) + 10), IntToGametypeName(netvote.gt_choice[map]), tflags, "small")

				--select border
				if (player.vote_slot == map) v.drawScaled((startX + (x*xoffset))*FU, (startY + (y*yoffset))*FU, picscale, v.cachePatch("SLCT1LVL"), V_SNAPTOLEFT) end

				--Player heads
				--My own head explodes programming thiS
				headX = 0
				headY = 0
				amountheads = 0

				for p in players.iterate do
					if ((p.voted) and (p.vote_slot == map))
						local head = v.getSprite2Patch(p.lastknownskin, SPR2_LIFE)
						local cmap = v.getColormap(nil, p.skincolor)
						amountheads = $ + 1
						headX = $ + 1
						v.draw((startX + (x*xoffset) + headStartXoffset + headX*headxoff), (startY + (y*yoffset) + headStartYoffset + headY*headyoff), head, V_SNAPTOLEFT, cmap)
						if (amountheads == 11 or amountheads == 22)
							headX = 0
							headY = $ + 1
						end
					end
				end
			end
		end

	elseif netvote.phase == IPH_END
		--Thumbnail picture of the winner
		local winner_pic = 0
		local pname = G_BuildMapName(netvote.decided_map) + "P"

		if v.patchExists(pname) winner_pic = v.cachePatch(pname)
		else winner_pic = v.cachePatch("BLANKLVL") end

		local runpos = 500 - 10 * (netvote.charruntime)
		local runframeamt = 4
		local tailframeamt = 4
		local tailframe = 0
		local tailsprite
		local tailoffsetx = 10
		local tailoffsety = 0

		if netvote.runskin == "tails"
			runframeamt = 2
			tailframe = (netvote.charruntime >> 1) % tailframeamt
			tailsprite = v.getSprite2Patch("tails", SPR2_TAL6, false, tailframe, 3)
		elseif netvote.runskin == "amy"
			runframeamt = 8
		elseif netvote.runskin == "fang"
			runframeamt = 6
		elseif netvote.runskin == "metalsonic"
			runframeamt = 1
			tailframeamt = 3
			tailframe = (netvote.charruntime >> 1) % tailframeamt
			tailsprite = v.getSpritePatch("JETF", tailframe)
			tailoffsetx = 18
			tailoffsety = -11
		end
		local runframe = (netvote.charruntime >> 1) % runframeamt
		local charcmap = v.getColormap(TC_ALLWHITE, SKINCOLOR_WHITE)
		local charsprite = v.getSprite2Patch(netvote.runskin, SPR2_RUN, false, runframe, 3)

		if tailsprite
			v.draw(runpos + 64 + tailoffsetx, 48 + tailoffsety, tailsprite, V_SNAPTORIGHT | V_SNAPTOTOP | V_80TRANS, charcmap)
			v.draw(runpos + 32 + tailoffsetx, 48 + tailoffsety, tailsprite, V_SNAPTORIGHT | V_SNAPTOTOP | V_60TRANS, charcmap)
			v.draw(runpos + tailoffsetx, 48 + tailoffsety, tailsprite, V_SNAPTORIGHT | V_SNAPTOTOP, charcmap)
		end
		v.draw(runpos + 64, 48, charsprite, V_SNAPTORIGHT | V_SNAPTOTOP | V_80TRANS, charcmap)
		v.draw(runpos + 32, 48, charsprite, V_SNAPTORIGHT | V_SNAPTOTOP | V_60TRANS, charcmap)
		v.draw(runpos, 48, charsprite, V_SNAPTORIGHT | V_SNAPTOTOP, charcmap)

		v.drawString(160, 16, "*DECISION*", V_SNAPTOBOTTOM, "center")
		v.draw(80, 32, winner_pic, V_SNAPTOBOTTOM)
		v.drawString(160, 144, "Speeding off to", V_ALLOWLOWERCASE | V_SNAPTOBOTTOM | V_GREENMAP, "center")
		v.drawString(160, 157, G_BuildMapTitle(netvote.decided_map) + MapGetAuthor(netvote.decided_map) + " (" + IntToGametypeName(netvote.decided_gt) + ")", V_ALLOWLOWERCASE | V_SNAPTOBOTTOM | V_YELLOWMAP, "thin-center")
		v.drawString(160, 170, "In " + (netvote.end_timeleft / TICRATE) + " seconds", V_ALLOWLOWERCASE | V_SNAPTOBOTTOM | V_GREENMAP, "center")
	end
end, "intermission") ]]

--- Map Rotation
--- By JJK, Meziu

-- TODO: implement shuffle
--local map_rotation_shuffle = CV_RegisterVar({"map_rotation_shuffle", "Off", CV_NETVAR, CV_OnOff})

--Netvars
rawset(_G, "rotation",{})
rotation.enabled_gametypes = {GT_RACE}
rotation.map_whitelist = {}
rotation.map_blacklist = {}
rotation.maplist = {}
--rotation.shuffled = false
rotation.decided_map = 1

addHook("NetVars", function(n)
	rotation = n($)
end)

--MapAvailableGametypes(m)
--Returns a table containing all gametype IDs that the map supports.
local function MapAvailableGametypes(m)
	local h = mapheaderinfo[m]
	if (not h)
		--print("ERROR: map "+ G_BuildMapTitle(m) +" has no header.")
		return nil
	end

	local gt = {}

	local tol_table = {
		[GT_COOP] = TOL_COOP,
		[GT_COMPETITION] = TOL_COMPETITION,
		[GT_RACE] = TOL_RACE,
		[GT_MATCH] = TOL_MATCH,
		[GT_TEAMMATCH] = TOL_MATCH,
		[GT_TAG] = TOL_TAG,
		[GT_HIDEANDSEEK] = TOL_TAG,
		[GT_CTF] = TOL_CTF
	}

	for i = GT_COOP,GAMETYPE_AMT_VANILLA do
		if (h.typeoflevel & tol_table[i]) then
			table.insert(gt, i)
		end
	end

	if (not #gt) then
		return nil
	end

	return gt
end

-- Scan the mapheaders to find all maps to rotate.
local scan_maps = function()
	rotation.maplist = {}
	for m = 1, #mapheaderinfo do
		if mapheaderinfo[m] then

			local in_whitelist = false

			-- If there isn't a whitelist (which means all maps are valid), or the map is in the whitelist
			if (not #rotation.map_whitelist) or table_contains_value(rotation.map_whitelist, m) then
				--print("Map "..m)
				in_whitelist = true
			end

			local gametype_is_available = false
			local supported_gametypes = MapAvailableGametypes(m)

			if supported_gametypes then
				for _,v in ipairs(supported_gametypes) do
					if table_contains_value(rotation.enabled_gametypes, v) then
						gametype_is_available = true
	
						break
					end
				end
			end

			local in_blacklist = false

			if table_contains_value(rotation.map_blacklist, m) then
				in_blacklist = true
			end

			if gametype_is_available and in_whitelist and not in_blacklist then
				-- print("Found map: " + m + " - " + G_BuildMapName(m) + " - " + G_BuildMapTitle(m))
				table.insert(rotation.maplist, m)
			end
		end
	end
end

--[[
local shuffle = function(tbl)
  for i = #tbl, 2, -1 do
    local j = P_RandomKey(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
  return tbl
end
]]

local get_index = function(mapnum)
    for k,v in ipairs(rotation.maplist) do
        if v == mapnum then
            return k
        end
    end

	return nil
end

local next_map = function()
    local index = get_index(gamemap)

	if index ~= nil then
		local newindex = (index % #rotation.maplist) + 1 -- Indices start at 1... smh

		--print("Maplist length: ", #rotation.maplist)
		--print("New index: ", newindex)
		--print("New map: ", rotation.maplist[newindex])

    	return rotation.maplist[newindex]
	end

	return nil
end

-- Decide the next map to play as soon as the current one loads
addHook("MapLoad", function(mapnum)
    G_SetCustomExitVars(next_map())
end)

COM_AddCommand("rotation_whitelist", function(player, ...)
	local args = {...}

    if args == nil or #args == 0 then
        local string = "Cleared the whitelist.\n"
        local usage = "rotation_whitelist <maps>:\nto set the maps that should be in the rotation.\ne.g. rotation_whitelist \"R0 R1 R2 RX\""

		rotation.map_whitelist = {}

        CONS_Printf(player, string)
        CONS_Printf(player, usage)
    else
        for i, map in pairs(args) do
            local mapnum = ExtMapNumToInt(map)
			
			if mapnum == nil then
				print("Invalid map: " + wl[i])
				return
			end
		
			table.insert(rotation.whitelist, mapnum)
			print("whitelisted map: " + mapnum)
        end
    end

	-- Rescan the maps
	scan_maps()
end, COM_ADMIN)

COM_AddCommand("rotation_blacklist", function(player, ...)
	local args = {...}

    if args == nil or #args == 0 then
        local string = "Cleared the blacklist.\n"
        local usage = "rotation_blacklist <maps>:\nto set the maps that should not be in the rotation.\ne.g. rotation_blacklist \"R0 R1 R2 RX\""

		rotation.map_blacklist = {}

        CONS_Printf(player, string)
        CONS_Printf(player, usage)
    else
        for i, map in pairs(args) do
            local mapnum = ExtMapNumToInt(map)
			
			if mapnum == nil then
				print("Invalid map: " + map)
				return
			end
		
			table.insert(rotation.map_blacklist, mapnum)
			print("blacklisted map: " + mapnum)
        end
    end

	-- Rescan the maps
	scan_maps()
end, COM_ADMIN)

COM_AddCommand("rotation_gametypelist", function(p, ...)
	local gt = {...}
	if ((gt == nil) or (#gt == 0)) then CONS_Printf(p, "Please supply a list of gametype numbers, separated by spaces.") end

	local egt = {}

	for i = 1, #gt do
		local gametype = tonumber(gt[i])
		
		if gametype == nil then
			print("Invalid gametype. Must be numeric.")
			return
		end

		if IntToGametypeName(gametype) == nil then
			print("Invalid gametype: " + gametype)
			return
		end

		table.insert(egt, gametype)
		print("Added gametype: " + IntToGametypeName(gametype))
	end

	rotation.enabled_gametypes = egt

	-- Rescan the maps
	scan_maps()
end, COM_ADMIN)

--- Highscore Show
--- By Meziu

local username = {}
local skin = {}
local time = {}
local full_rows = 0
local used_row = 0
local no_time = true

local function receive_data(source, type, target, msg)
	if msg:sub(0, 5) == "UXDFS"
		local data_msg = msg:sub(6)
		
		full_rows = full_rows + 1
		
		local first_comma = data_msg:find(",")
		local second_comma = data_msg:find(",", first_comma+1)
		
		username[full_rows] = data_msg:sub(0, first_comma-1)
		skin[full_rows] = data_msg:sub(first_comma+1, second_comma-1)
		time[full_rows] = data_msg:sub(second_comma+1)
		return true
	end
end
addHook("PlayerMsg", receive_data)


local function reset_on_map_change(mapnum)
	username = {}
	skin = {}
	time = {}
	full_rows = 0
	used_row = 0
end
addHook("MapLoad", reset_on_map_change)


local function find_in_array(array, value)
	for k, v in ipairs(array) do
		if v == value
			return k
		end
	end
	return -1
end


local function check_player_skin(player)
	if player == displayplayer
		used_row = find_in_array(skin, player.mo.skin)
		
		if used_row == -1
			no_time = true
		else
			no_time = false
		end
	end
end
addHook("PlayerThink", check_player_skin)


local function show_score(v)
	if no_time
		v.drawString(4, 173, "NO BEST TIME YET, BE FIRST TO FINISH!", 45056)
	else
		v.drawString(4, 173, "BEST TIME FOR " + string.upper(skin[used_row]) + ":", 45056)
		v.drawString(4, 182, time[used_row]+" by "+username[used_row])
	end
	
end
hud.add(show_score, "scores")



-- Fang un-damage
-- By Lamibe

-- If a player hit someone directly or using a projectile the damage will be canceled
--
addHook("ShouldDamage", function(target, inflictor, source, damage)
	if not (target and inflictor) then return end
	if inflictor.type == MT_PLAYER or (source and source.type == MT_PLAYER) then return false end
end, MT_PLAYER)



-- Skin Lock
-- By Meziu, JJK, Lamibe, LeonardoTheMutant

addHook("MobjDeath", function(target)
    target.player.oldskin = target.skin
end, MT_PLAYER)

addHook("PlayerThink", function(player)
    if player.playerstate == 1 then --player is dead
        COM_BufInsertText(player, "skin " + player.oldskin)
        R_SetPlayerSkin(player, player.oldskin)
    end
end)
