# Plugin List

List of all plugins and their purpose.    

## NavBot Autobalance

This plugin automatically move bots on team games to balance them.    
TF2 doesn't need this plugin.    
The plugin only supports games with two teams.    

## NavBot Quota

Adds a bot quota system.    
A config file will be auto generated in `cfg/sourcemod`.    

## NavBot Hearing

General purpose plugin to implement a basic sound events for NavBots, allowing them to react to sounds.    
A config file will be auto generated in `cfg/sourcemod`.    

Convars:    

- sm_nbhm_footsteps_enabled: Controls if the plugin should emit sound events for player footsteps.

### Hearing Module Notes

* Players are determined to be making noise based on speed

## NavBot Nav Mesh Manager

[Go to page.](NAVMESH_MANAGER.md)

## NavBot Left 4 Dead Compatibility

This plugin handles replacing survivor bots with NavBots.    
Requires [Left 4 DHooks Direct](https://forums.alliedmods.net/showthread.php?t=321696).    

## Common Nav Blockers

Implements nav auto blockers for common entities.    
Specific blockers can be disabled in the auto generated config file.    

## Spawn Point Checker

Simple plugin for finding map spawnpoints without a nav area nearby.    
Use the `sm_check_spawnpoints` admin command to run the check. Results are written to a log file saved inside SourceMod's logs folder.    

## ZPS Nav Blockers

Implements automatic nav area blockers for ZPS's `func_humanclip` and `func_zombieclip` entities.    

## NavBot Stuck Logger

Logs bot stuck events to a custom file.    
Optional per map log file and stuck event count threshold, check auto generated config.   

## ZPS Objective Support

[Go to page.](ZPS_OBJ_SUPPORT.md)
