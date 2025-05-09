--[[
=====================================
| author: Nkfree                    |
| github: https://github.com/Nkfree |
==========================================================================================================================================
| description: A script that aims to fix CompanionShare so that it would work with in multiplayer conditions.                            |
|              UI should update accordingly when multiple players have the Companion Share opened for the same companion.                |
|                                                                                                                                        |
| installation:                                                                                                                          |
|   1. Create a folder named companionShare in <tes3mp>/server/scripts/custom/                                                           |
|   2. Download main.lua and add it to that newly created companionShare folder                                                          |
|   3. Open customScripts.lua and add there the following line: require("custom.companionShare.main")                                    |
|   4. Save customScripts.lua and launch the server                                                                                      |
|   5. To confirm that the script is running, you should see "[CompanionShare] Running..." among the first few lines of server console   |
|                                                                                                                                        |
| changelog:                                                                                                                             |
|   1.3 - fix generated record items, such as those obtained from enchanting, not being saved                                            |
|   1.2 - initialize inventory for objects without one to prevent crash                                                                  |
|       - added additional reset of worldPlacedItem in OnPlayerInventoryHandler to prevent ignoring addition of the item with the same   |
|         properties (as the one that was previously dropped into the world) to companion's inventory                                    |
|       - removed check for whether companion has object data in cell - this should not happen, will be investigated if crash occurs     |
|   1.1 - removed timer for checking player standing still, newly the IsStandingStill function is called on relevant events              |
|       - worldPlacedItem is now reset to empty table instead of nil to prevent crash when calling tableHelper.isEqualTo with nil value  |
|       - OnObjectDialogueChoice uses validator instead of handler as a callback, newly the companion's inventory is force loaded        |
|         upon player selecting 'Companion Share' dialogue to prevent observed desync connected with other player modifying the contents |
|         behind the scenes                                                                                                              |
|   1.0 - initial version                                                                                                                |
|                                                                                                                                        |
| known limitations:                                                                                                                     |
|   1. - if player closes 'Companion Share', yet does not move and other player modifies the inventory of the same companion,            |
|        the companion will be reactivated for the player and 'Companion Share' opened, this is due to me not knowing of a way to        |
|        determine, whether the player has closed the inventory or not -> this can be avoided by slightly moving/turning upon closure    |
==========================================================================================================================================
]]

local script = {}

script.OnServerPostInitHandler = function(eventStatus)
    tes3mp.LogMessage(enumerations.log.INFO, "[CompanionShare] Running...")
end

script.IsPlayerLoggedIn = function(pid)
    return Players[pid] ~= nil and Players[pid]:IsLoggedIn()
end

-- Returns true if player's position/rotation has not changed since activation of Companion Share, false otherwise.
script.IsStandingStill = function(pid)
    local lastPosX = Players[pid].companionShare.lastKnownPosition.posX
    local lastPosY = Players[pid].companionShare.lastKnownPosition.posY
    local lastPosZ = Players[pid].companionShare.lastKnownPosition.posZ
    local lastRotX = Players[pid].companionShare.lastKnownPosition.rotX
    local lastRotZ = Players[pid].companionShare.lastKnownPosition.rotZ

    if lastPosX ~= tes3mp.GetPosX(pid) then return false end
    if lastPosY ~= tes3mp.GetPosY(pid) then return false end
    if lastPosZ ~= tes3mp.GetPosZ(pid) then return false end
    if lastRotX ~= tes3mp.GetRotX(pid) then return false end
    if lastRotZ ~= tes3mp.GetRotZ(pid) then return false end

    return true
end

-- Validator that force loads the inventory of the companion for the player, it seems that if there are any changes done to the companion inventory while player does not have it open
-- the inventory is not synced upon opening without the force load.
-- Tracks player's position/rotation and companion uniqueIndex upon activating Companion Share.
-- Lastly it also creates a helper variable to detect an item that has been removed from player's inventory, yet dropped into the world instead of into the companion's inventory.
script.OnObjectDialogueChoiceValidator = function(eventStatus, pid, cellDescription, objects)
    local cell = LoadedCells[cellDescription]

    for uniqueIndex, object in pairs(objects) do
        if object.dialogueChoiceType == enumerations.dialogueChoice.COMPANION_SHARE and cell ~= nil and cell:ContainsObject(uniqueIndex) then
            if script.IsPlayerLoggedIn(pid) then

                -- Initialize inventory for object without one
                if cell.data.objectData[uniqueIndex].inventory == nil then
                    cell.data.objectData[uniqueIndex].inventory = {}
                end

                cell:LoadContainers(pid, cell.data.objectData, {uniqueIndex})

                Players[pid].companionShare = {
                    companionIndex = uniqueIndex,
                    lastKnownPosition = {
                        posX = tes3mp.GetPosX(pid),
                        posY = tes3mp.GetPosY(pid),
                        posZ = tes3mp.GetPosZ(pid),
                        rotX = tes3mp.GetRotX(pid),
                        rotZ = tes3mp.GetRotZ(pid)
                    },
                    worldPlacedItem = {}
                }
            end
        end
    end
end

-- Handler that tracks an item dropped by the player into the world (OnObjectPlace event is fired earlier than OnPlayerInventory).
script.OnObjectPlaceHandler = function(eventStatus, pid, cellDescription, objects)
    for uniqueIndex, object in pairs(objects) do
        if object.droppedByPlayer then
            if script.IsPlayerLoggedIn(pid) and Players[pid].companionShare ~= nil then
                Players[pid].companionShare.worldPlacedItem = {refId = object.refId, enchantmentCharge = object.enchantmentCharge, count = object.count, charge = object.charge, soul = object.soul}
            end
        end
    end
end

-- Handler that:
-- a) checks whether the item the packet is about has not been dropped into the world by player in the previous OnObjectPlace event - if so, it empties the worldPlacedItem and returns
-- b) adds an item to companion's inventory and updates the UI accordingly for other players that may have the Companion Share activated for the same uniqueIndex
-- c) removes an item (or part of it) from the companion's inventory and updates the UI accordingly for other players that may have the Companion Share activated for the same uniqueIndex
script.OnPlayerInventoryHandler = function(eventStatus, pid, playerPacket)
    if not script.IsPlayerLoggedIn(pid) then return end

    local cellDescription = tes3mp.GetCell(pid)
    local cell = LoadedCells[cellDescription]
    local item = playerPacket.inventory[1]

    if Players[pid].companionShare ~= nil and cell ~= nil then
        if not script.IsStandingStill(pid) then
            Players[pid].companionShare = nil
            return
        end

        if tableHelper.isEqualTo(item, Players[pid].companionShare.worldPlacedItem) then
            Players[pid].companionShare.worldPlacedItem = {}
            return
        end

        Players[pid].companionShare.worldPlacedItem = {} -- reset the worldPlacedItem also here in case player dropped an item with the same properties in the world as well as the companion's inventory

        local companionIndex = Players[pid].companionShare.companionIndex

        local companionInventory = cell.data.objectData[companionIndex].inventory

        if playerPacket.action == enumerations.inventory.ADD then
            inventoryHelper.removeExactItem(companionInventory, item.refId, item.count, item.charge, item.enchantmentCharge, item.soul)
            if logicHandler.IsGeneratedRecord(item.refId) then
                local recordStore = logicHandler.GetRecordStoreByRecordId(item.refId)

                if recordStore ~= nil then
                    cell:RemoveLinkToRecord(recordStore.storeType, item.refId, companionIndex)
                end
            end
            script.UpdateContainerUiForOthers(pid, cellDescription, companionIndex, cell.data.objectData[companionIndex].refId)
        elseif playerPacket.action == enumerations.inventory.REMOVE then
            inventoryHelper.addItem(companionInventory, item.refId, item.count, item.charge, item.enchantmentCharge, item.soul)
            if logicHandler.IsGeneratedRecord(item.refId) then
                local recordStore = logicHandler.GetRecordStoreByRecordId(item.refId)

                if recordStore ~= nil then
                    cell:AddLinkToRecord(recordStore.storeType, item.refId, companionIndex)
                end
            end
            script.UpdateContainerUiForOthers(pid, cellDescription, companionIndex, cell.data.objectData[companionIndex].refId)
        end
    end
end

-- A workaround to update the UI of the companion's inventory for other players that may have it opened,
-- it executes the 'ToggleMenus' command twice for the other player (who has the companion's inventory opened), first one to hide the UI, second one to refresh it,
-- then it force loads the inventory of the companion that has been updated via the OnPlayerInventory handler for the other player.
-- Last but not least it activates the companion for the other player again and lastly it selects the Companion Share for them - this should be seamless, other player should only notice the inventory of the companion
-- being updated, no other artifacts.
script.UpdateContainerUiForOthers = function(pid, cellDescription, companionIndex, refId)
    local cell = LoadedCells[cellDescription]

    for opid, _ in pairs(Players) do
        if opid ~= pid and script.IsPlayerLoggedIn(opid) and Players[opid].companionShare ~= nil and Players[opid].companionShare.companionIndex == companionIndex and cell ~= nil then
            if script.IsStandingStill(opid) then
                logicHandler.RunConsoleCommandOnPlayer(opid, "ToggleMenus", false)
                logicHandler.RunConsoleCommandOnPlayer(opid, "ToggleMenus", false)
                cell:LoadContainers(opid, cell.data.objectData, {companionIndex})
                logicHandler.ActivateObjectForPlayer(opid, cellDescription, companionIndex)

                tes3mp.ClearObjectList()
                tes3mp.SetObjectListPid(opid)
                tes3mp.SetObjectListCell(cellDescription)

                local splitIndex = companionIndex:split("-")
                tes3mp.SetObjectRefNum(splitIndex[1])
                tes3mp.SetObjectMpNum(splitIndex[2])

                tes3mp.SetObjectRefId(refId)
                tes3mp.SetObjectDialogueChoiceType(enumerations.dialogueChoice.COMPANION_SHARE)
                tes3mp.AddObject()

                tes3mp.SendObjectDialogueChoice(false, false)
            else
                Players[opid].companionShare = nil
            end
        end
    end
end

customEventHooks.registerHandler("OnServerPostInit", script.OnServerPostInitHandler)
customEventHooks.registerHandler("OnObjectDialogueChoice", script.OnObjectDialogueChoiceValidator)
customEventHooks.registerHandler("OnObjectPlace", script.OnObjectPlaceHandler)
customEventHooks.registerHandler("OnPlayerInventory", script.OnPlayerInventoryHandler)
