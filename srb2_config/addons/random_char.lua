addHook("MapChange", function()
    local skin = skins[P_RandomKey(6)].name -- 6 base skins
    COM_BufInsertText(server, "forceskin " + skin)
end)
