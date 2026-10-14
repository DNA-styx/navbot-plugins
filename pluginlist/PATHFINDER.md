# Pathfinder

A simple fun plugin that allows players to pathfind to other players.    

## Commands

|Name|Description|Usage|Default Access|
|:---:|:---:|:---:|:---:|
|sm_pathfind|Toggles the pathfinding|To enable pathfinding, pass the target player name as the first argument. To disable pathfiding, call without any args.|Cheats|

## ConVars

|Name|Description|
|:---:|:---:|
|sm_pathfinder_max_per_cycle|Maximum number of players to update in a single think cycle.|
|sm_pathfinder_path_update_frequency|Frequency of path updates in seconds.|
|sm_pathfinder_think_frequency|How frequently the plugin thinks in seconds.|
|sm_pathfinder_max_segments|Maximum number of path segments to draw in a single path update.|

## Notes

A NavBot nav mesh must be available for the current map for this plugin to work.    

