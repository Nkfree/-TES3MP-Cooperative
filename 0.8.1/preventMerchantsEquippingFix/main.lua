--[[
=====================================
| author: Nkfree                    |
| github: https://github.com/Nkfree |
=====================================
]]

local script = {}

script.equipmentBackup = {}

function script.OnServerPostInitHandler(eventStatus)
	tes3mp.LogMessage(1, "[PreventMerchantsEqupping] Running...")
end

function script.OnObjectMiscellaneousValidator(eventStatus, pid, cellDescription, objects, targetPlayers)
	local cell = LoadedCells[cellDescription]

	if cell == nil then return end

	for uniqueIndex, object in pairs(objects) do
		local newGoldPool = object.goldPool
		local oldGoldPool = cell.data.objectData[uniqueIndex].goldPool

		if oldGoldPool ~= nil then
			local goldDifference = oldGoldPool - newGoldPool

			-- Actor's gold has decreased, assume they have bought something
			-- Backup their equipment for later use in OnActorEquipmentHandler
			if goldDifference < 0 then
				script.equipmentBackup[uniqueIndex] = tableHelper.deepCopy(cell.data.objectData[uniqueIndex].equipment)
			end
		end
	end
end

function script.OnActorEquipmentHandler(eventStatus, pid, cellDescription, actors)
	local cell = LoadedCells[cellDescription]

	if cell == nil then return end

	for uniqueIndex, _ in pairs(actors) do
		-- Restore the backed up equipment if it exists
		if script.equipmentBackup[uniqueIndex] ~= nil then
			cell.data.objectData[uniqueIndex].equipment = tableHelper.deepCopy(script.equipmentBackup[uniqueIndex])
			script.equipmentBackup[uniqueIndex] = nil
			cell:LoadActorEquipment(pid, cell.data.objectData, { uniqueIndex })
		end
	end
end

customEventHooks.registerValidator("OnObjectMiscellaneous", script.OnObjectMiscellaneousValidator)
customEventHooks.registerHandler("OnServerPostInit", script.OnServerPostInitHandler)
customEventHooks.registerHandler("OnActorEquipment", script.OnActorEquipmentHandler)
