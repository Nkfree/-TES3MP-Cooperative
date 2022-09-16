# -TES3MP-Cooperative

Directory of scripts suited for coop, related to specific versions of TES3MP.

## Inspect Player Equipment

A server-side script that allows players to inspect other player's equipment. The displayed container should reflect on the equipment changes dynamically.

I imagined the following kinds of scenarios while creating this:\
*Player1*: What do you think is a better weapon, this one?\
*Player2*: Wait, let me see... Alright, this looks good...\
*Player1*: And what about this one?\
*Player2*: Alright, you got higher stats on that, I'd go for the second one.

### Showcase:

[![Inspect Player Equipment showcase](https://i.ytimg.com/vi/jYykZKEXkjU/hqdefault.jpg)](https://youtu.be/jYykZKEXkjU)

### Usage (command in chat):

**/gear pid** - default command to view equipment of pid that matches online player and is not yourself\
  *the command can be changed in the script via script.config.inspectCommand*

### Installation:

<ol>
  <li>Create a folder inspectPlayerEquipment in <tes3mp>/server/scripts/custom</li>                                              
  <li>Add main.lua in that created folder</li>                                                                                   
  <li>Open customScripts.lua and put there this line: require("custom.inspectPlayerEquipment.main")</li>                         
  <li>Save customScripts.lua and launch the server</li>                                                           
  <li>To confirm the script is running fine, you should see "[InspectPlayerEquipment] Running..." among the few first lines of server console</li>
</ol>

## Player Kill Count

A server-side script that separates kills for players. Kills are shared only among players who are killer's allies and happen to be within the configured radius relative to the killer. This should encourage players to engage in combat cooperatively while not punishing those that have fallen slightly behind to loot a previous corpse or drink a potion.
This is beneficial when players prefer to keep individual path in questing (meaning different houses and guilds) but still want to benefit from the coop aspect in cases where quests require certain actors killed for completion. There can also be a case where Player1 and Player2 quest together, while Player3 is offline. Why should the Player3 have the kill assigned to them when they didn't obviously earn it? They players can then return to the same spot with Player3 once he is online, however this still requires having a means of resetting a cell or respawning those actors, which is out of scope of this script.

### Optional file:

[*namesData.lua*](https://github.com/Nkfree/-TES3MP-resources/blob/main/namesData.lua) -
this maps refIds to names from Construction Set, beware that multiple refIds can reference the same name, for example\
Cave Rat can be referenced by both "rat_cave_fgrh" and "rat_cave_fgt", therefore you might see 2 entries being shown in /showkills gui box for Cave Rat, if you have at least one kill per both of those Cave Rat refIds, this does not have any effect on journal

### Notes:

This script is meant to be used with separated player journals achieved by setting **config.shareJournal = false** in *<tes3mp>/server/scripts/config.lua*

**limitedRefIds.lua** and related implementation should ensure that certain refIds do not exceed predefined kill count, thus making specific quests completable, covers Morrowind, Tribunal and Bloodmoon at the time being

### TODO:

Add a way to synchronize related global variables per player - I have an idea

### Showcase:

[![Player Kill Count showcase](https://i.ytimg.com/vi/MmBB2YjxivQ/hqdefault.jpg)](https://youtu.be/MmBB2YjxivQ)

### Usage (commands in chat):

**/showkills** - lists all your killed refIds or their names (see *Optional file*) and their count in a gui box

**/resetkills pid** - resets kills of player specified by their pid, resets your kills if pid is not specified, overrides default /resetkills command\
&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;- you must be eligible to reset ranks, see configurables       

### Configurables

**script.config.radius = 3200**\
Radius (in units) within which ally needs to be relative to pid during the kill. Single cell is 8192 units large which is equivalent of 128 yards. The default value 3200 is equal to 50 yards. This is approximatelly what the 3200 units look like:
[![Default radius](https://github.com/Nkfree/-TES3MP-Script-images/blob/main/playerKillCount/default_radius.png)]()

**script.config.resetKillsRankSelf = 0**\
0 - everyone is allowed to reset their kills, 1 - moderator, 2 - admin, 3 - server owner

**script.config.resetKillsRankOther = 3**\
0 - everyone is allowed to reset other players' kills, 1 - moderator, 2 - admin, 3 - server owner

### Installation (if you do not wish to use namesData.lua, please skip to 3.):

<ol>
 <li>Create a folder resources in <tes3mp>/server/scripts/custom/</li>                                              
  <li>Download namesData.lua from the previously mentioned link and add it in that folder created above</li>           
  <li>Create a folder playerKillCount in <tes3mp>/server/scripts/custom/</li>
  <li>Download limitedRefIds.lua and add it to that newly created playerKillCount folder</li>
  <li>Download main.lua and add it to that newly created playerKillCount folder</li>                                                           
  <li>Open customScripts.lua and put there this line: require("custom.playerKillCount.main")</li>
  <li>Save customScripts.lua and launch the server</li>
  <li>To confirm the script is running fine, you should see "[PlayerKillCount] Running..." among the first few lines of server console</li>
</ol>


### Credits:
*Rickoff* - **limitedRefIds.lua** and related implementation, see *Notes* for more info
