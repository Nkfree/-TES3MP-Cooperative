--[[
=====================================
| author: Nkfree                    |
| github: https://github.com/Nkfree |
================================================================================================================================================
| description:                                                                                                                                 |
| Tes3mp script that uses chat to display (monitor) health, magicka and fatigue percentage of allied players.                                  |
| History of messages is preserved such that if you switch the monitoring off you will be able to restore and display last N chat messages,    |
| where N is defined by main.configurables.keepMessagesLimit.                                                                                  |
| Health, magicka and fatigue values are obtained from clients via client-side script, where client sends updates to server everytime          |
| the value of the stat that has chaned by - I believe - at least a single point. This ensures the accurate stats data is received in contrary |
| to output from tes3mp stats getters. This may result in packet spam, therefore I suggest to use this in rather closed sessions (e.g. COOP).  |
| The way this script manages sending of chat messages should ensure it is compatible with other scripts handling OnPlayerSendMessage events.  |
|                                                                                                                                              |
| known issues:                                                                                                                                |
| 1. Due to default font not being monospaced I was not able to properly format the chat output. I had in mind to create a nicer               |
|    looking effect, where each ally name with stats would be displayed in a frame made of symbols but since each character has different      |
|    width, the formatting would always fall apart. Therefore I decided to go for a simpler look.                                              |
|                                                                                                                                              |
| 2. I could not decide on or figure out an ideal way to limit the count of allies displayed. Should it be managed via menu where player gets  |
|    to choose which players to display? Or should the display amount be limited to N while the names would be rotated based on who has the    |
|    least health?                                                                                                                             |
|                                                                                                                                              |
|                                                                                                                                              |
| commands to use in chat:                                                                                                                     |
|   /as - default command to toggle monitoring of allies' stats (health, magicka, fatigue) in chat window                                      |
| installation:                                                                                                                                |
|   1. Create a folder allyStatsChat in <tes3mp>/server/scripts/custom                                                                         |
|   2. Add main.lua in that created folder                                                                                                     |
|   3. Open customScripts.lua and put there this line: require("custom.allyStatsChat.main")                                                    |
|   4. Save customScripts.lua and launch the server                                                                                            |
|   5. To confirm the script is running fine, you should see "[AllyStatsChat] Running..." among the first few lines of server console          |
================================================================================================================================================
--]]
local main = {}

main.configurables = {}
main.configurables.colorHealth = color.Red
main.configurables.colorMagicka = color.Blue
main.configurables.colorFatigue = color.Green
main.configurables.commandToggleAllyStats = "as"
main.configurables.keepMessagesLimit = 20 -- How many regular messages should be kept per player

main.allyStatsChatMessageComponents = {}
main.allyStatsChatMessageComponents.verticalSeparator = "||"
main.allyStatsChatMessageComponents.statsLineFormat = "%s\t%s\t\t%s\t\t%s\t\t%s\t%s"

main.script = {}
main.script.id = "ally_stats"
main.script.text =
    "begin " .. main.script.id .. "\n" ..
    "    set as_health to GetHealth\n" ..
    "    set as_magicka to GetMagicka\n" ..
    "    set as_fatigue to GetFatigue\n" ..
    "end " .. main.script.id .. "\n"

--[[ Helper functions --]]
local function GetPidByName(name)
    for pid, player in pairs(Players) do
        if player.accountName == name then
            return pid
        end
    end

    return nil
end

-- Removes spaces within the name and preserves first 20 characters
local function GetShortenedName(name)
    return name:gsub("%s+", ""):sub(1, 20)
end

--[[
    Redefine tes3mp.SendMessage to extend the default behaviour.
    Every time the original tes3mp.SendMessage is called, it will now also append the message
    to affected player's linked list of messages so that these can be restored later.
    Moreover, main.tes3mpSendMessage preserves the default behaviour so that messages regarding
    update of ally stats are not appended to the linked lists of messages.
    This is a hacky way but covers more cases than using an OnPlayerSendMessage validator, because
    it is unclear how many custom validators user has already set up and how messages are handled within those.
    Redefining the function (variable respectively) allows to provide extended functionality without interfering
    with those custom validators.
--]]
main.tes3mpSendMessage = tes3mp.SendMessage

tes3mp.SendMessage = function(pid, message, sendToOtherPlayers, skipAttachedPlayer)
    sendToOtherPlayers = sendToOtherPlayers or false
    skipAttachedPlayer = skipAttachedPlayer or false

    local affectedPids = {}

    -- Gather affected pids
    if sendToOtherPlayers then
        for otherPid, _ in pairs(Players) do
            if not (skipAttachedPlayer and otherPid == pid) then
                table.insert(affectedPids, otherPid)
            end
        end
    else
        table.insert(affectedPids, pid)
    end

    --[[
        Update affected pids.
        Do not send regular message to players who are currently monitoring stats of their allies.
    --]]
    for _, affectedPid in ipairs(affectedPids) do
        main.AppendMessagePlayerLinkedList(affectedPid, message)

        if not Players[affectedPid].allyStats.statsRunning then
            main.tes3mpSendMessage(affectedPid, message)
        end
    end
end

--[[Message history management--]]
function main.AppendMessagePlayerLinkedList(pid, message)
    local messagesLinkedList = Players[pid].allyStats.messagesLinkedList

    local messageNode = { value = message, next = nil }

    if messagesLinkedList.count == 0 then
        messagesLinkedList.head = messageNode
        messagesLinkedList.tail = messageNode
    else
        messagesLinkedList.tail.next = messageNode
        messagesLinkedList.tail = messagesLinkedList.tail.next
    end

    if messagesLinkedList.count >= main.configurables.keepMessagesLimit then
        messagesLinkedList.head = messagesLinkedList.head.next
    else
        messagesLinkedList.count = messagesLinkedList.count + 1
    end
end

function main.RestorePlayerMessages(pid, messageNode)
    if messageNode == nil then return end

    main.tes3mpSendMessage(pid, messageNode.value)
    return main.RestorePlayerMessages(pid, messageNode.next)
end

--[[ Custom script and global variables management --]]
function main.CreateScript(pid)
    local recordData = { id = main.script.id, scriptText = main.script.text }

    tes3mp.ClearRecords()
    tes3mp.SetRecordType(enumerations.recordType.SCRIPT)
    packetBuilder.AddScriptRecord(main.script.id, recordData)

    tes3mp.SendRecordDynamic(pid, false, false)
end

function main.CreateStatsGlobalVariables(pid)
    local varTable = {
        variableType = enumerations.variableType.FLOAT,
        floatValue = -1
    }

    Players[pid].allyStats.variables = {
        as_health = tableHelper.deepCopy(varTable),
        as_magicka = tableHelper.deepCopy(varTable),
        as_fatigue = tableHelper.deepCopy(varTable)
    }
end

function main.SendStatsGlobalVariables(pid)
    tes3mp.ClearClientGlobals()
    tes3mp.ClearSynchronizedClientScriptIds()
    tes3mp.AddSynchronizedClientScriptId(main.script.id)

    for varId, varTable in pairs(Players[pid].allyStats.variables) do
        tes3mp.AddClientGlobalFloat(varId, varTable.floatValue)
        tes3mp.AddSynchronizedClientGlobalId(varId)
    end

    tes3mp.SendClientScriptGlobal(pid)
    tes3mp.SendClientScriptSettings(pid)
end

function main.RunScriptForPlayer(pid)
    logicHandler.RunConsoleCommandOnPlayer(pid, "startscript " .. main.script.id, false)
end

--[[ Ally stats monitoring management --]]
function main.GetAllyData(pid, allyPid, allyName)
    if Players[allyPid].allyStats.variables == nil then
        return nil
    end

    local health = Players[allyPid].allyStats.variables.as_health.floatValue
    local magicka = Players[allyPid].allyStats.variables.as_magicka.floatValue
    local fatigue = Players[allyPid].allyStats.variables.as_fatigue.floatValue

    if Players[pid].allyStats.allyData[allyName].health == health and Players[pid].allyStats.allyData[allyName].magicka == magicka and Players[pid].allyStats.allyData[allyName].fatigue == fatigue then
        return nil
    end

    Players[pid].allyStats.allyData[allyName].health = health
    Players[pid].allyStats.allyData[allyName].magicka = magicka
    Players[pid].allyStats.allyData[allyName].fatigue = fatigue

    local healthPercent = math.floor(health / tes3mp.GetHealthBase(allyPid) * 100)
    local magickaPercent = math.floor(magicka / tes3mp.GetMagickaBase(allyPid) * 100)
    local fatiguePercent = math.floor(fatigue / tes3mp.GetFatigueBase(allyPid) * 100)

    return {
        shortName = Players[allyPid].allyStats.shortenedName,
        healthPercentString = tostring(healthPercent) .. "%",
        magickaPercentString = tostring(magickaPercent) .. "%",
        fatiguePercentString = tostring(fatiguePercent) .. "%"
    }
end

function main.GetAllyMessage(allyShortenedName, healthPercentString, magickaPercentString, fatiguePercentString)
    local verticalSeparator = main.allyStatsChatMessageComponents.verticalSeparator

    local allyStatsLine = string.format(
        main.allyStatsChatMessageComponents.statsLineFormat,
        color.GoldenRod .. verticalSeparator,
        allyShortenedName,
        main.configurables.colorHealth .. healthPercentString,
        main.configurables.colorMagicka .. magickaPercentString,
        main.configurables.colorFatigue .. fatiguePercentString,
        color.GoldenRod .. verticalSeparator
    )

    local message = allyStatsLine .. color.Default .. "\n\n"
    return message
end

function main.StartMonitorAllyStatsChat(pid)
    Players[pid].allyStats.timer = tes3mp.CreateTimerEx("AS_UpdateAllyStatsChat", 1, "i", pid)
    Players[pid].allyStats.statsRunning = true
    tes3mp.StartTimer(Players[pid].allyStats.timer)
end

function main.StopMonitorAllyStatsChat(pid)
    tes3mp.StopTimer(Players[pid].allyStats.timer)
    Players[pid].allyStats.timer = nil
    Players[pid].allyStats.statsRunning = false
    Players[pid].allyStats.allyData = {}
    tes3mp.CleanChatForPid(pid)
    main.RestorePlayerMessages(pid, Players[pid].allyStats.messagesLinkedList.head)
end

function main.ToggleMonitorAllyStatsChat(pid, cmd)
    if Players[pid].allyStats.timer == nil then
        main.StartMonitorAllyStatsChat(pid)
    else
        main.StopMonitorAllyStatsChat(pid)
    end
end

function AS_UpdateAllyStatsChat(pid)
    for _, allyName in ipairs(Players[pid].data.alliedPlayers) do
        local allyPid = GetPidByName(allyName)

        if allyPid ~= nil then
            if Players[pid].allyStats.allyData[allyName] == nil then Players[pid].allyStats.allyData[allyName] = {} end
            local allyData = main.GetAllyData(pid, allyPid, allyName)

            if allyData ~= nil then
                Players[pid].allyStats.allyData[allyName].message = main.GetAllyMessage(allyData.shortName,
                    allyData.healthPercentString,
                    allyData.magickaPercentString,
                    allyData.fatiguePercentString)

                Players[pid].allyStats.shouldUpdateChat = true
            end
        end
    end

    if Players[pid].allyStats.shouldUpdateChat then
        tes3mp.CleanChatForPid(pid)
        local message = ""

        for _, allyData in pairs(Players[pid].allyStats.allyData) do
            message = message .. allyData.message
        end

        --[[
            Quit monitoring if no ally available.
            We get here after monitored all monitored allies have disconnected.
        --]]
        if message == "" then
            return main.StopMonitorAllyStatsChat(pid)
        end

        main.tes3mpSendMessage(pid, message)
    end

    Players[pid].allyStats.shouldUpdateChat = false
    tes3mp.RestartTimer(Players[pid].allyStats.timer, 100)
end

--[[ Commands, Handlers and Validators management --]]
function main.OnServerPostInitHandler(eventStatus)
    tes3mp.LogMessage(enumerations.log.INFO, "[AllyStatsChat] Running...")
end

function main.OnPlayerConnectValidator(eventStatus, pid)
    Players[pid].allyStats = {}
    Players[pid].allyStats.allyData = {}
    Players[pid].allyStats.messagesLinkedList = { count = 0 }
    Players[pid].allyStats.shouldUpdateChat = false -- make it accessible from outside so that disconnecting player can notify allies monitoring them
end

function main.OnPlayerAuthentifiedHandler(eventStatus, pid)
    Players[pid].allyStats.shortenedName = GetShortenedName(Players[pid].accountName)
    Players[pid].allyStats.statsRunning = false
    Players[pid].allyStats.timer = nil

    main.CreateScript(pid)
    main.CreateStatsGlobalVariables(pid)
    main.SendStatsGlobalVariables(pid, main.script.id)
    main.RunScriptForPlayer(pid)
end

function main.OnClientScriptGlobalValidator(eventStatus, pid, variables)
    for id, variable in pairs(variables) do
        if Players[pid].allyStats.variables[id] ~= nil then
            Players[pid].allyStats.variables[id].floatValue = variable.floatValue
            --[[
                Do not cancel other validators or handlers.
                Rather delete the variable and pass empty table to ensure compatibility with other scripts,
                in case there were multiple variable stored within the table.
                This approach also ensures these script's globals are not processed by default handler,
                therefore are not stored within the players' data file.
            --]]
            variables[id] = nil
        end
    end
end

function main.OnPlayerDisconnectValidator(eventStatus, pid)
    if Players[pid].allyStats.statsRunning then
        main.StopMonitorAllyStatsChat(pid)
    end

    --[[
        Remove self from stats monitoring of other allies.
        Ensure other ally also updates their chat window.
    --]]
    local accountName = Players[pid].accountName
    for otherPid, _ in pairs(Players) do
        if Players[otherPid].allyStats.statsRunning and Players[otherPid].allyStats.allyData[accountName] ~= nil then
            Players[otherPid].allyStats.allyData[accountName] = nil
            Players[otherPid].allyStats.shouldUpdateChat = true
        end
    end

    --[[
        Further cleanup not needed as all player related data is temporarily stored within Players[pid] instance,
        that gets destroyed once disconnect process has been finished.
    --]]
end

customEventHooks.registerHandler("OnServerPostInit", main.OnServerPostInitHandler)
customEventHooks.registerValidator("OnPlayerConnect", main.OnPlayerConnectValidator)
customEventHooks.registerHandler("OnPlayerAuthentified", main.OnPlayerAuthentifiedHandler)

customEventHooks.registerValidator("OnClientScriptGlobal", main.OnClientScriptGlobalValidator)
customEventHooks.registerValidator("OnPlayerDisconnect", main.OnPlayerDisconnectValidator)

customCommandHooks.registerCommand(main.configurables.commandToggleAllyStats, main.ToggleMonitorAllyStatsChat)
