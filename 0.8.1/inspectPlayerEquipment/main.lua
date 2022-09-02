--[[
=====================================
| author: Nkfree                    |
| github: https://github.com/Nkfree |
| installation:                     |=========================================================================================
|   1. Create folder inspectPlayerEquipment in <tes3mp>/server/scripts/custom                                                |
|   2. Add main.lua in that created folder                                                                                   |
|   3. Open customScripts.lua and put there this line: require("custom.inspectPlayerEquipment.main")                         |
|   4. Save customScripts.lua and launch the server                                                                          |
|   5. To confirm the script is running fine, you should see "[InspectPlayerEquipment] Running..." among the few first lines |
==============================================================================================================================
]]

local script = {}

script.config = {}
script.config.inspectCommand = "gear"; -- Command usable in chat

script.containersData = {}

script.containerRecord = {
    id = "inspect",
    data = {
        baseId = "chest_small_01",
        name = "Inspecting %s's equipment ..."
    }
}

script.messages = {}
script.messages["forbidSelfInspect"] = "You cannot inspect yourself.";
script.messages["unloggedPid"] = "Cannot inspect unlogged player.";
script.messages["wrongCmd"] = "Wrong command:\n/" ..
    script.config.inspectCommand .. " <pid> OR /" .. script.config.inspectCommand .. " <name>";

function script.GetInspectingPids(pid)
    local inspectingPids = {}

    for inspectingPid, containerData in pairs(script.containersData) do
        if containerData.targetPid == pid then
            table.insert(inspectingPids, inspectingPid)
        end
    end

    return inspectingPids
end

function script.GetNameByPid(pid)
    if script.IsPlayerLoggedIn(pid) then
        return Players[pid].accountName
    end

    return nil
end

function script.GetPidByName(name)
    for pid, player in pairs(Players) do
        if string.lower(player.accountName) == string.lower(name) and Players[pid]:IsLoggedIn() then
            return pid
        end
    end

    return nil
end

function script.IsPlayerLoggedIn(pid)
    return Players[pid] ~= nil and Players[pid]:IsLoggedIn()
end

function script.NotifyPlayer(pid, msg)
    tes3mp.SendMessage(pid, color.Yellow .. msg .. "\n" .. color.Default, false)
end

function script.AddContainerData(pid, targetPid, cellDescription, uniqueIndex)
    script.containersData[pid] = {
        cellDescription = cellDescription,
        itemsToRetrieve = {},
        targetPid = targetPid,
        uniqueIndex = uniqueIndex,
    }
end

function script.AddItemToRetrive(containerData, item)
    table.insert(containerData.itemsToRetrieve, item)
end

function script.RemoveItemToRetrieve(containerData, item)
    tableHelper.removeValue(containerData.itemsToRetrieve, item)

    for index, itemToRetrieve in ipairs(containerData.itemsToRetrieve) do
        if tableHelper.isEqualTo(item, itemToRetrieve) then
            containerData.itemsToRetrieve[index] = nil
        end
    end
end

function script.RemoveContainerData(pid)
    script.containersData[pid] = nil
end

function script.RetrieveItems(pid, itemArray)
    local containerData = script.containersData[pid]

    for _, item in ipairs(itemArray) do
        inventoryHelper.addItem(Players[pid].data.inventory, item.refId, item.count, item.charge, item.enchantmentCharge
            , item.soul)
        script.RemoveItemToRetrieve(containerData, item)
    end

    Players[pid]:LoadItemChanges(itemArray, enumerations.inventory.ADD)
end

function script.SendContainerRecord(pid, targetPid)
    local targetName = script.GetNameByPid(targetPid)

    if targetName ~= nil then
        local recordId = script.containerRecord.id
        local recordData = {
            baseId = script.containerRecord.data.baseId,
            name = string.format(script.containerRecord.data.name, targetName)
        }

        tes3mp.ClearRecords()
        tes3mp.SetRecordType(enumerations.recordType.CONTAINER)

        packetBuilder.AddContainerRecord(recordId, recordData)
        tes3mp.SendRecordDynamic(pid, false, false)

        return true
    end

    return false
end

function script.PlaceContainerInPlayerCell(pid)
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

    local objectData = dataTableBuilder.BuildObjectData(script.containerRecord.id)
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

function script.ActivateContainer(pid, cellDescription, uniqueIndex)
    if not script.IsPlayerLoggedIn(pid) then return end
    logicHandler.ActivateObjectForPlayer(pid, cellDescription, uniqueIndex)
end

function script.UpdateContainerItems(pid)
    local containerData = script.containersData[pid]

    if containerData == nil or not script.IsPlayerLoggedIn(containerData.targetPid) then return end

    local targetEquipment = Players[containerData.targetPid].data.equipment

    tes3mp.ClearObjectList()
    tes3mp.SetObjectListPid(pid)
    tes3mp.SetObjectListCell(containerData.cellDescription)

    local splitIndex = containerData.uniqueIndex:split("-")
    tes3mp.SetObjectRefNum(splitIndex[1])
    tes3mp.SetObjectMpNum(splitIndex[2])
    tes3mp.SetObjectRefId(script.containerRecord.id)

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

-- Create new container record, send the record to pid, add related data, gather items from inspected player and activate it for the pid
function script.ShowContainer(pid, targetPid)
    local hasSent = script.SendContainerRecord(pid, targetPid)
    if not hasSent then return end

    local cellDescription, uniqueIndex = script.PlaceContainerInPlayerCell(pid)
    if cellDescription == nil or uniqueIndex == nil then return end

    script.AddContainerData(pid, targetPid, cellDescription, uniqueIndex)
    script.UpdateContainerItems(pid)
    script.ActivateContainer(pid, cellDescription, uniqueIndex)
end

function script.DeleteContainerFromWorld(pid)
    local containerData = script.containersData[pid]

    if containerData == nil or not script.IsPlayerLoggedIn(pid) then return end

    -- Cover case where cell is no longer loaded
    local unloadCellAtEnd = false
    if LoadedCells[containerData.cellDescription] == nil then
        unloadCellAtEnd = true
        logicHandler.LoadCellForPlayer(pid, containerData.cellDescription)
    end

    tes3mp.ClearObjectList()
    tes3mp.SetObjectListPid(pid)
    tes3mp.SetObjectListCell(containerData.cellDescription)
    packetBuilder.AddObjectDelete(containerData.uniqueIndex, {})
    tes3mp.SendObjectDelete(false)

    if unloadCellAtEnd then
        logicHandler.UnloadCellForPlayer(pid, containerData.cellDescription)
    end
end

-- Remove container from world as well as data
function script.RemoveContainer(pid)
    script.DeleteContainerFromWorld(pid)
    script.RemoveContainerData(pid)
end

function script.OnServerPostInitHandler(eventStatus)
    tes3mp.LogMessage(1, "[InspectPlayerEquipment] Running...")
end

-- If the cell is about to be unloaded, destroy the container for player otherwise it will not get properly updated after the transfer to another cell
function script.OnCellUnloadValidator(eventStatus, pid, cellDescription)
    local containerData = script.containersData[pid]

    if containerData == nil or containerData.cellDescription ~= cellDescription then return end

    script.RemoveContainer(pid)
end

function script.OnContainerValidator(eventStatus, pid, cellDescription, objects)
    for objectIndex, object in ipairs(objects) do
        local containerData = script.containersData[pid]

        if containerData ~= nil and object.uniqueIndex == containerData.uniqueIndex then
            local action = tes3mp.GetObjectListAction()
            local containerSubAction = tes3mp.GetObjectListContainerSubAction()

            -- Remember the items the pid tried to add to the container
            -- so that it can be caught in the OnPlayerInventory packet and retrieved to the pid
            -- this should prevent pid from losing items dragged and dropped to this container
            if action == enumerations.container.ADD then
                for itemIndex = 0, tes3mp.GetContainerChangesSize(objectIndex - 1) - 1 do
                    local item = {
                        refId = tes3mp.GetContainerItemRefId(objectIndex - 1, itemIndex),
                        count = tes3mp.GetContainerItemCount(objectIndex - 1, itemIndex),
                        charge = tes3mp.GetContainerItemCharge(objectIndex - 1, itemIndex),
                        enchantmentCharge = tes3mp.GetContainerItemEnchantmentCharge(objectIndex - 1, itemIndex),
                        soul = tes3mp.GetContainerItemSoul(objectIndex - 1, itemIndex)
                    }

                    script.AddItemToRetrive(containerData, item)

                end
                -- Container gets closed upon selecting Take All, therefore remove it
            elseif containerSubAction == enumerations.containerSub.TAKE_ALL then
                script.RemoveContainer(pid)
            end

            return customEventHooks.makeEventStatus(false, false)
        end
    end
end

function script.OnPlayerEquipmentHandler(eventStatus, pid, playerPacket)
    local inspectingPids = script.GetInspectingPids(pid)

    -- Update container items for all players currently inspecting this pid
    for _, inspectingPid in ipairs(inspectingPids) do
        if script.IsPlayerLoggedIn(inspectingPid) then
            script.UpdateContainerItems(inspectingPid)
        end
    end
end

function script.OnPlayerInventoryHandler(eventStatus, pid, playerPacket)
    local containerData = script.containersData[pid]
    if playerPacket.action ~= enumerations.inventory.REMOVE or containerData == nil or
        #containerData.itemsToRetrieve <= 0 then return end

    script.RetrieveItems(pid, playerPacket.inventory)
end

function script.OnPlayerDisconnectValidator(eventStatus, pid)
    -- Remove containers for all players inspecting this pid
    local inspectingPids = script.GetInspectingPids(pid)
    for _, inspectingPid in ipairs(inspectingPids) do
        if script.IsPlayerLoggedIn(inspectingPid) then
            script.RemoveContainer(inspectingPid)
        end
    end

    -- Remove container for this pid if exists
    local containerData = script.containersData[pid]
    if containerData ~= nil then
        script.RemoveContainer(pid)
    end
end

function script.OnInspectCommand(pid, cmd)
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

customEventHooks.registerValidator("OnCellUnload", script.OnCellUnloadValidator)
customEventHooks.registerValidator("OnContainer", script.OnContainerValidator)
customEventHooks.registerValidator("OnPlayerDisconnect", script.OnPlayerDisconnectValidator)

customEventHooks.registerHandler("OnServerPostInit", script.OnServerPostInitHandler)
customEventHooks.registerHandler("OnPlayerEquipment", script.OnPlayerEquipmentHandler)
customEventHooks.registerHandler("OnPlayerInventory", script.OnPlayerInventoryHandler)

customCommandHooks.registerCommand("gear", script.OnInspectCommand)
