
BasementRenovator = BasementRenovator or { subscribers = {} }
BasementRenovator.mod = RegisterMod('BasementRenovator', 1)

local function log(msg)
    msg = '[BasementRenovator] ' .. tostring(msg)
    print(msg)
    Isaac.DebugString(msg)
end

local function fireCallback(name, ...)
    for _, sub in pairs(BasementRenovator.subscribers) do
        callback = sub[name]
        if callback then
            local result = callback(...)
            if result ~= nil then return result end
        end
    end
end

local success, data = pcall(require, 'roomTest')
if success then
    BasementRenovator.TestRoomData = data
else
    log(data) -- error
end

if not BasementRenovator.TestRoomData then
    log('No room to test; please disable the mod')
    return
else
    local room = BasementRenovator.TestRoomData
    log('TEST METHOD: ' .. BasementRenovator.TestRoomData.TestType)
    log('TEST STAGE: ' .. room.Stage .. '.' .. room.StageType)
    log('TEST ROOM: ' .. room.Type .. '.' .. room.Variant .. '.' .. room.Subtype)
end

function BasementRenovator:InTestRoom()
    local test = BasementRenovator.TestRoomData

    local t, v, s = test.Type, test.Variant, test.Subtype

    local level = Game():GetLevel()
    local desc = level:GetCurrentRoomDesc()
    local data = desc.Data
    if data.Type == t and data.Variant == v and data.Subtype == s then
        return desc
    end
end

local badShapes = {
    [2] = true,
    [3] = true,
    [5] = true,
    [7] = true
}
BasementRenovator.mod:AddCallback(ModCallbacks.MC_POST_CURSE_EVAL, function(_, curse)
    local test = BasementRenovator.TestRoomData

    if test.TestType == 'StageReplace' and badShapes[test.Shape] then
        log('Forcing XL due to room shape!')
        return curse | LevelCurse.CURSE_OF_LABYRINTH
    end
end)

BasementRenovator.mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function()
    local test = BasementRenovator.TestRoomData

    if test.TestType == 'StageReplace' then
        Game():GetPlayer(0):AddCollectible(CollectibleType.COLLECTIBLE_MIND, 0, false)
        Game():GetSeeds():AddSeedEffect(SeedEffect.SEED_PREVENT_CURSE_LOST)
    end
end)

local typeToSuffix = {
    [StageType.STAGETYPE_ORIGINAL] = "",
    [StageType.STAGETYPE_WOTL] = "a",
    [StageType.STAGETYPE_AFTERBIRTH] = "b"
}
BasementRenovator.mod:AddCallback(ModCallbacks.MC_POST_CURSE_EVAL, function()
    local test = BasementRenovator.TestRoomData
    -- For whatever reasons, callbacks execute when the stage command is run from the console,
    -- but don't when used from lua
    -- This may be patched in Rep, so fix this then so the callback doesn't happen twice
    -- Use CURSE_EVAL because otherwise it'll usually happen after other level detection code

    if test.TestType ~= 'InstaPreview' then
        local level = Game():GetLevel()
        if not (level:GetStage() == test.Stage and
                level:GetStageType() == test.StageType) then

            local stage, type = test.Stage, test.StageType
            type = typeToSuffix[type] or ''

            Isaac.ExecuteCommand('stage ' .. stage .. type)
        end
    end

    fireCallback('TestStage', BasementRenovator.TestRoomData)
end)

BasementRenovator.mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function()
    local desc = BasementRenovator:InTestRoom()
    if desc then
        fireCallback('TestRoom', BasementRenovator.TestRoomData, desc)
    end
end)

BasementRenovator.mod:AddCallback(ModCallbacks.MC_PRE_ROOM_ENTITY_SPAWN, function(_, ...)
    local desc = BasementRenovator:InTestRoom()
    if desc then
        local replacement = fireCallback('TestRoomEntitySpawn', BasementRenovator.TestRoomData, desc, ...)
        if replacement then
            return replacement
        end
    end
end)

BasementRenovator.mod:AddCallback(ModCallbacks.MC_POST_RENDER, function()
    local test = BasementRenovator.TestRoomData
    local desc = BasementRenovator:InTestRoom()

    local pos = Game():GetRoom():GetRenderSurfaceTopLeft() * 2 + Vector(-20,286) --Vector(442,286)
    Isaac.RenderScaledText("BASEMENT RENOVATOR TEST: " .. test.Name .. " (" .. test.Variant .. ")", pos.X, pos.Y - 20, 0.5, 0.5, 255, 255, 0, 0.75)
    Isaac.RenderScaledText("Test Type: " .. test.TestType .. " --- In Test Room: " .. (desc and 'YES' or 'NO'), pos.X, pos.Y - 12, 0.5, 0.5, 255, 255, 0, 0.75)
end)