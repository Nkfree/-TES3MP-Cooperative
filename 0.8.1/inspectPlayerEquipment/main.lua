--[[
=====================================
| author: Nkfree                    |
| github: https://github.com/Nkfree |
=====================================
]]

local script = {}

script.config = {}
script.config.inspectCommand = "gear"; -- Command usable in chat

script.containersData = {}

script.containerRecord = {
    baseId = "chest_small_01",
    id = "inspect",
    name = "Inspecting %s's equipment ..."
}

script.messages = {}
script.messages["forbidSelfInspect"] = "You cannot inspect yourself.";
script.messages["unloggedPid"] = "Cannot inspect unlogged player.";
script.messages["wrongCmd"] = "Wrong command:\n/" ..
    script.config.inspectCommand .. " <pid> OR /" .. script.config.inspectCommand .. " <name>";

script.GetInspectingPids = function(pid)
    local inspectingPids = {}

    for inspectingPid, containerData in pairs(script.containersData) do
        if containerData.targetPid == pid then
            table.insert(inspectingPids, inspectingPid)
        end
    end

    return inspectingPids
end

script.GetNameByPid = function(pid)
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        return Players[pid].accountName
    end

    return nil
end

script.GetPidByName = function(name)
    for pid, player in pairs(Players) do
        if string.lower(player.accountName) == string.lower(name) and Players[pid]:IsLoggedIn() then
            return pid
        end
    end

    return nil
end

script.IsPlayerLoggedIn = function(pid)
    return Players[pid] ~= nil and Players[pid]:IsLoggedIn()
end

script.NotifyPlayer = function(pid, msg)
    tes3mp.SendMessage(pid, color.Yellow .. msg .. "\n" .. color.Default, false)
end

script.AddContainerData = function(pid, targetPid, cellDescription, recordId, uniqueIndex)
    script.containersData[pid] = {
        cellDescription = cellDescription,
        targetPid = targetPid,
        recordId = recordId,
        uniqueIndex = uniqueIndex,
    }
end

script.RemoveContainerData = function(pid)
    script.containersData[pid] = nil
end

script.CreateSendContainerRecord = function(pid, targetPid)
    local targetName = script.GetNameByPid(targetPid)

    if targetName ~= nil then
        local recordId = script.containerRecord.id
        local recordData = {
            baseId = script.containerRecord.baseId,
            name = string.format(script.containerRecord.name, targetName)
        }

        tes3mp.ClearRecords()
        tes3mp.SetRecordType(enumerations.recordType.CONTAINER)

        packetBuilder.AddContainerRecord(recordId, recordData)
        tes3mp.SendRecordDynamic(pid, false, false)

        return recordId
    end

    return nil
end

script.PlaceContainerInPlayerCell = function(pid, recordId)
    if not script.IsPlayerLoggedIn(pid) then return nil end

    local cellDescription = tes3mp.GetCell(pid)
    local location = {
        posX = tes3mp.GetPosX(pid),
        posY = tes3mp.GetPosY(pid),
        posZ = -8000,
        rotX = 0,
        rotY = 0,
        rotZ = 0
    }

    local objectData = dataTableBuilder.BuildObjectData(recordId)
    objectData.location = location

    local mpNum = WorldInstance:GetCurrentMpNum() + 1
    local uniqueIndex = 0 .. "-" .. mpNum
    WorldInstance:SetCurrentMpNum(mpNum)
    tes3mp.SetCurrentMpNum(mpNum)

    tes3mp.ClearObjectList()
    tes3mp.SetObjectListPid(pid)
    tes3mp.SetObjectListCell(cellDescription)
    tes3mp.SetObjectRefId(objectData.refId)
    tes3mp.SetObjectRefNum(0)
    tes3mp.SetObjectMpNum(mpNum)
    tes3mp.SetObjectCount(objectData.count)
    tes3mp.SetObjectCharge(objectData.charge)
    tes3mp.SetObjectEnchantmentCharge(objectData.enchantmentCharge)
    tes3mp.SetObjectSoul(objectData.soul)
    tes3mp.SetObjectPosition(objectData.location.posX, objectData.location.posY, objectData.location.posZ)
    tes3mp.SetObjectRotation(objectData.location.rotX, objectData.location.rotY, objectData.location.rotZ)
    tes3mp.AddObject()

    tes3mp.SendObjectPlace()

    return cellDescription, uniqueIndex
end

script.ActivateContainer = function(pid, cellDescription, uniqueIndex)
    if not script.IsPlayerLoggedIn(pid) then return end
    logicHandler.ActivateObjectForPlayer(pid, cellDescription, uniqueIndex)
end

script.UpdateContainerItems = function(pid)
    local containerData = script.containersData[pid]

    if containerData == nil or not script.IsPlayerLoggedIn(containerData.targetPid) then return end

    local targetEquipment = Players[containerData.targetPid].data.equipment

    tes3mp.ClearObjectList()
    tes3mp.SetObjectListPid(pid)
    tes3mp.SetObjectListCell(containerData.cellDescription)

    local splitIndex = containerData.uniqueIndex:split("-")
    tes3mp.SetObjectRefNum(splitIndex[1])
    tes3mp.SetObjectMpNum(splitIndex[2])
    tes3mp.SetObjectRefId(containerData.recordId)

    for _, item in pairs(targetEquipment) do
        local refId = item.refId

        if refId ~= nil and refId ~= "" then
            local count = item.count or 1
            local charge = item.charge or -1
            local enchantmentCharge = item.enchantmentCharge or -1
            local soul = item.soul or ""
            tes3mp.SetContainerItemRefId(item.refId)
            tes3mp.SetContainerItemCount(count)
            tes3mp.SetContainerItemCharge(charge)
            tes3mp.SetContainerItemEnchantmentCharge(enchantmentCharge)
            tes3mp.SetContainerItemSoul(soul)

            tes3mp.AddContainerItem()
        end
    end

    tes3mp.AddObject()
    tes3mp.SetObjectListAction(enumerations.container.SET)
    tes3mp.SendContainer(false, false)
end

-- Create new container record, add related data, gather items from inspected player and activate it for the pid
script.ShowContainer = function(pid, targetPid)
    local recordId = script.CreateSendContainerRecord(pid, targetPid)
    if recordId == nil then return end

    local cellDescription, uniqueIndex = script.PlaceContainerInPlayerCell(pid, recordId)
    if cellDescription == nil or uniqueIndex == nil then return end

    script.AddContainerData(pid, targetPid, cellDescription, recordId, uniqueIndex)
    script.UpdateContainerItems(pid)
    script.ActivateContainer(pid, cellDescription, uniqueIndex)
end

script.DeleteContainerFromWorld = function(pid)
    local containerData = script.containersData[pid]

    if containerData == nil or not script.IsPlayerLoggedIn(pid) then return end

    tes3mp.ClearObjectList()
    tes3mp.SetObjectListPid(pid)
    tes3mp.SetObjectListCell(containerData.cellDescription)
    packetBuilder.AddObjectDelete(containerData.uniqueIndex, {})
    tes3mp.SendObjectDelete(false)
end

-- Remove container from world as well as data
script.RemoveContainer = function(pid)
    script.DeleteContainerFromWorld(pid)
    script.RemoveContainerData(pid)
end

script.OnContainerValidator = function(eventStatus, pid, cellDescription, objects)
    for _, object in pairs(objects) do
        local containerData = script.containersData[pid]

        if containerData ~= nil and object.uniqueIndex == containerData.uniqueIndex then
            local containerSubAction = tes3mp.GetObjectListContainerSubAction()

            -- Container gets closed upon selecting Take All, therefore remove it
            if containerSubAction == enumerations.containerSub.TAKE_ALL then
                script.RemoveContainer(pid)
            end

            return customEventHooks.makeEventStatus(false, false)
        end
    end
end

script.OnPlayerEquipmentHandler = function(eventStatus, pid, playerPacket)
    local inspectingPids = script.GetInspectingPids(pid)

    -- Update container items for all players currently inspecting this pid
    for _, inspectingPid in ipairs(inspectingPids) do
        if Players[inspectingPid] ~= nil and Players[inspectingPid]:IsLoggedIn() then
            script.UpdateContainerItems(inspectingPid)
        end
    end
end

script.OnPlayerDisconnectValidator = function(eventStatus, pid)
    -- Remove containers for all players inspecting this pid
    local inspectingPids = script.GetInspectingPids(pid)
    for _, inspectingPid in ipairs(inspectingPids) do
        if Players[inspectingPid] ~= nil and Players[inspectingPid]:IsLoggedIn() then
            script.RemoveContainer(inspectingPid)
        end
    end

    -- Remove container for this pid if exists
    local containerData = script.containersData[pid]
    if containerData ~= nil then
        script.RemoveContainer(pid)
    end
end

script.OnGearCommand = function(pid, cmd)
    local targetName = tableHelper.concatenateArrayValues(cmd, 2)
    local targetPid = tonumber(cmd[2]) or script.GetPidByName(targetName)

    -- Notify player in case of any errors
    if targetPid == pid then
        return script.NotifyPlayer(pid, script.messages.forbidSelfInspect)
    elseif targetPid == nil then
        return script.NotifyPlayer(pid, script.messages.wrongCmd)
    elseif not script.IsPlayerLoggedIn(targetPid) then
        return script.NotifyPlayer(pid, script.messages.unloggedPid)
    end

    -- Remove previous container if exists
    local containerData = script.containersData[pid]
    if containerData ~= nil then
        script.RemoveContainer(pid)
    end

    -- Create and show the new container
    script.ShowContainer(pid, targetPid)
end

customEventHooks.registerValidator("OnContainer", script.OnContainerValidator)
customEventHooks.registerValidator("OnPlayerDisconnect", script.OnPlayerDisconnectValidator)

customEventHooks.registerHandler("OnPlayerEquipment", script.OnPlayerEquipmentHandler)

customCommandHooks.registerCommand("gear", script.OnGearCommand)
