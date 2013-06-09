
This tool is only useful if you're running a multiplayer minetest server.

Requirements: rollback enabled

Configuration: Edit the following line in init.lua to represent the location of your rollback.txt:
                  inspector.rollback_file = 'rollback.txt';


Ingame, do a /giveme inspector:inspector, wield the tool (looks like a wooden axe),
and left- or rightclick on the node you want to run rollback_check on.
Note: The mod greps the rollback.txt file and DOES NOT use the internal /rollback_check command.
Only the specified node is searched.
All recorded actions - or, more precisely, the last inspector.show_max_amount (default:20) known actions -
on that particular node are listed.
To get further information about what an actor on that node did immediately before and after that action,
run e.g. the chatcommand /inspector 4   (to get more information about the 4th listed action)
