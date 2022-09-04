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

A server-side script that separates kills for players so that those aren't shared per world
