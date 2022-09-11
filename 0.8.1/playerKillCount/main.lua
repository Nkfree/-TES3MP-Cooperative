--[[
=====================================
| author: Nkfree                    |
| github: https://github.com/Nkfree |
==========================================================================================================================================
| optional: namesData.lua that can be downloaded from https://github.com/Nkfree/-TES3MP-resources/blob/main/namesData.lua,               |
|           this maps refIds to names, beware that multiple refIds can reference the same name - for example Cave Rat,                   |
|           that will result in multiple entries of Cave Rat in /showkills gui box, because there is "rat_cave_fgrh" and "rat_cave_fgt"  |
| note: this is to be used with separated journals achieved by setting config.shareJournal = false in <tes3mp>/server/scripts/config.lua |
| commands to use in chat:                                                                                                               |
|   /showkills - displays gui box with all the refIds (or names) you have killed and their respective kill counts                        |
|   /resetkills or /resetkills pid - resets your or others' kills if you have sufficient permissions, refer to script.config for ranks   |
| installation - if you don't wish to use namesData.lua, please skip to 3.:                                                              |
|   1. Create data folder in <tes3mp>/server/data/custom/playerKillCount                                                                 |
|   2. Download limitedRefIds.json and add it in that folder created above                                                               |
|   3. Create resources folder in <tes3mp>/server/scripts/custom/                                                                        |
|   4. Download namesData.lua and add it in that folder created above                                                                    |
|   5. Create a folder playerKillCount in <tes3mp>/server/scripts/custom/                                                                |
|   6. Download main.lua and add it to that newly created playerKillCount folder                                                         |
|   7. Open customScripts.lua and put there this line: require("custom.playerKillCount.main")                                            |
|   8. Save customScripts.lua and launch the server                                                                                      |
|   9. To confirm the script is running fine, you should see "[PlayerKillCount] Running..." among the first few lines of server console  |
==========================================================================================================================================
]]

local limitedRefIds = jsonInterface.load("custom/playerkillCount/limitedRefIds.json")

local script = {}

script.config = {}
script.config.radius = 3200 -- radius within which ally needs to be in relative to pid during the kill; in units; cell is 8192 units large which is equivalent of 128 yards; default value 3200 is equal to 50 yards
script.config.resetKillsRankSelf = 0 -- 0 - everyone is allowed to reset their kills, 1 - moderator, 2 - admin, 3 - server owner
script.config.resetKillsRankOther = 3 -- 0 - everyone is allowed to reset other players' kills, 1 - moderator, 2 - admin, 3 - server owner

script.messages = {}
script.messages["lowRankForReset"] = "You do not meet permissions to reset %s kills."
script.messages["unloggedResetPid"] = "You cannot reset kills for unlogged player."
script.messages["successReset"] = "You have successfully reset %s kills."

script.messages.subjects = {
    your = "your",
    other = "another player's"
}

script.namesData = prequire("custom.resources.namesData") or {}

script.GetPidByName = function(name)
    for pid, playerData in pairs(Players) do
        if string.lower(playerData.accountName) == string.lower(name) then
            return pid
        end
    end

    return nil
end

function script.GetNameByPid(pid)
    if script.IsPlayerLoggedIn(pid) then
        return Players[pid].accountName
    end

    return nil
end

function script.IsPlayerLoggedIn(pid)
    return Players[pid] ~= nil and Players[pid]:IsLoggedIn()
end

function script.NotifyPlayer(pid, msg)
    tes3mp.SendMessage(pid, color.Yellow .. msg .. "\n" .. color.Default, false)
end

-- Save kill in player's data
script.SaveKill = function(pid, refId)
    if Players[pid].data.kills[refId] == nil then
        Players[pid].data.kills[refId] = 1
    else
        Players[pid].data.kills[refId] = Players[pid].data.kills[refId] + 1
    end
end

function script.LoadKill(pid, refId)
    -- Imporant to send the count even if the player doesn't have any kills for that refId
    -- otherwise default handlers will increment it for them anyway, that explains the 0
    local count = limitedRefIds[refId] or Players[pid].data.kills[refId] or 0

    tes3mp.ClearKillChanges(pid)
    tes3mp.AddKill(refId, count)
    tes3mp.SendWorldKillCount(pid, false)
end

-- This is imporant because if you don't reload/override the kills for everyone (event if the count would be 0)
-- default handlers will ensure that the kills are incrementing for everyone,
-- directly related to the comment above in script.LoadKill
function script.LoadKillForEveryOne(refId)
    for pid, _ in pairs(Players) do
        if script.IsPlayerLoggedIn(pid) then
            script.LoadKill(pid, refId)
        end
    end
end

-- Loads all kills stored in player's data
-- Using this instead of calling LoadKill per every refId,
-- so that there is single packet being sent instead of multiple
-- TODO: didn't figure out smarter solution, return to it later
function script.LoadKills(pid)
    tes3mp.ClearKillChanges(pid)

    for refId, count in pairs(Players[pid].data.kills) do
        tes3mp.AddKill(refId, limitedRefIds[refId] or count)
    end

    tes3mp.SendWorldKillCount(pid, false)
end

-- Support players in engaging the coop experience together
-- while not punishing them for falling behind
function script.IsKillEligible(pid, pidCellDescription, allyPid)
    local isPidInExterior = tes3mp.IsInExterior(pid)
    local isAllyInExterior = tes3mp.IsInExterior(allyPid)

    -- Pid and allyPid must both be either in exterior or in interior
    if isPidInExterior ~= isAllyInExterior then
        return false
    end

    local allyCellDescription = tes3mp.GetCell(allyPid)

    -- Interior cells must match
    if not isPidInExterior and pidCellDescription ~= allyCellDescription then
        return false
    end

    -- Both in interior and exterior the allyPid needs to be within the radius of pid
    return script.IsInRadius(pid, allyPid)
end

-- Calculate whether pid and allyPid are within
-- a predefined radius
function script.IsInRadius(pid, allyPid)
    local radius = script.config.radius

    local pidLocation = {
        posX = tes3mp.GetPosX(pid),
        posY = tes3mp.GetPosY(pid),
        posZ = tes3mp.GetPosZ(pid)
    }

    local allyPidLocation = {
        posX = tes3mp.GetPosX(allyPid),
        posY = tes3mp.GetPosY(allyPid),
        posZ = tes3mp.GetPosZ(allyPid)
    }

    local deltaPosX = math.abs(allyPidLocation.posX - pidLocation.posX)
    local deltaPosY = math.abs(allyPidLocation.posY - pidLocation.posY)
    local deltaPosZ = math.abs(allyPidLocation.posZ - pidLocation.posZ)

    local distance = math.sqrt(deltaPosX ^ 2 + deltaPosY ^ 2 + deltaPosZ ^ 2)

    return distance <= radius
end

-- Delete any world kills on connect
function script.OnServerPostInitHandler(eventStatus)
    if next(WorldInstance.data.kills) then
        WorldInstance.data.kills = {}
        WorldInstance:QuicksaveToDrive()
    end

    tes3mp.LogMessage(enumerations.log.INFO, "[PlayerKillCount] Running...")

    -- Register it here because of how eventHandler adds additional handlers
    -- see eventHandler.InitializeDefaultHandlers for reference
    customEventHooks.registerHandler("OnActorDeath", script.OnActorDeathHandler)
end

-- Load player's saved kills on login
function script.OnPlayerAuthentifiedHandler(eventStatus, pid)
    if Players[pid].data.kills == nil then Players[pid].data.kills = {} end
    script.LoadKills(pid)
end

-- Disable default OnWorldKillCount event behaviour
function script.OnWorldKillCountValidator(eventStatus, pid)
    return customEventHooks.makeEventStatus(false, false)
end

function script.OnActorDeathHandler(eventStatus, pid, cellDescription, actors)

    for _, actor in pairs(actors) do
        if actor.killer.pid ~= nil then
            local killerPids = { actor.killer.pid }
            -- Gather allied pids to share kills within the party
            for _, allyName in ipairs(Players[actor.killer.pid].data.alliedPlayers) do
                local allyPid = script.GetPidByName(allyName)

                if script.IsPlayerLoggedIn(allyPid) and script.IsKillEligible(pid, cellDescription, allyPid) then
                    table.insert(killerPids, allyPid)
                end
            end
            -- Save the kills for the killer and anyone in the killer's party if they are eligible
            for _, killerPid in ipairs(killerPids) do
                script.SaveKill(killerPid, string.lower(actor.refId))
            end
        end

        -- Additional handler present in eventHandler forces ActorDeath kill to be loaded for everyone
        -- so reload them for everyone based on their actual saved kills
        script.LoadKillForEveryOne(string.lower(actor.refId))
    end
end

function script.ResetKills(pid)
    if not script.IsPlayerLoggedIn(pid) then return end

    for refId, _ in pairs(Players[pid].data.kills) do
        Players[pid].data.kills[refId] = 0
    end

    -- Load kills for pid
    script.LoadKills(pid)
end

-- Resets kills of targetPid or pid if pid meets rank requirement
-- if there is targetPid specified tries to reset kills for that targetPid instead,
-- this command overrides original reset kills command
function script.OnResetKillsCommand(pid, cmd)
    local targetPid = tonumber(cmd[2]) or pid

    -- Handle targetPid not logged in
    if not script.IsPlayerLoggedIn(targetPid) then
        return script.NotifyPlayer(pid, script.messages.unloggedResetPid)
    end

    local staffRank = Players[pid].data.settings.staffRank
    local messageSubject = nil
    local targetName = nil

    if targetPid == pid then
        messageSubject = script.messages.subjects.your
    else
        messageSubject = script.messages.subjects.other
        targetName = script.GetNameByPid(targetPid)
    end

    -- Handle insufficient ranks
    if targetPid == pid and staffRank < script.config.resetKillsRankSelf or
        targetPid ~= pid and staffRank < script.config.resetKillsRankOther then
        local lowRankMessage = string.format(script.messages.lowRankForReset, messageSubject)
        return script.NotifyPlayer(pid, lowRankMessage)
    end

    script.ResetKills(targetPid)

    -- Handle successful reset
    if targetName == nil then
        targetName = messageSubject
    end

    local successMessage = string.format(script.messages.successReset, targetName)
    return script.NotifyPlayer(pid, successMessage)
end

-- Displays total amount of player kills as well as complete list of killed actors and their respective count
function script.OnShowKillsCommand(pid, cmd)
    local label = "- Player Kills -\n\n"
    local totalKills = 0
    local items = ""
    local sorted = {}

    for refId, count in pairs(Players[pid].data.kills) do
        -- Use namesData.lua if available
        local actorName = script.namesData[string.lower(refId)] or string.lower(refId)
        table.insert(sorted, { name = actorName, count = count })
    end

    -- Sort the refIds by name
    table.sort(sorted, function(a, b)
        return a.name < b.name
    end)

    -- Add listbox items
    for _, data in ipairs(sorted) do
        totalKills = totalKills + data.count
        items = items .. data.name .. ": " .. data.count .. "\n"
    end

    label = label .. "Total: " .. totalKills

    return tes3mp.ListBox(pid, -1, label, items)
end

customEventHooks.registerHandler("OnServerPostInit", script.OnServerPostInitHandler)
customEventHooks.registerHandler("OnPlayerAuthentified", script.OnPlayerAuthentifiedHandler)
customEventHooks.registerValidator("OnWorldKillCount", script.OnWorldKillCountValidator)

customCommandHooks.registerCommand("resetkills", script.OnResetKillsCommand)
customCommandHooks.registerCommand("showkills", script.OnShowKillsCommand)
