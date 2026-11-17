# NavBot Quota Module: Ignore Spectators

Module for the NavBot bot quota plugin.    
Makes players in unassigned and spectators team not count towards the number of players in-game.    

## ConVars

| Name | Description |
|:---:|:---:|
| sm_navbot_quota_ignore_unassigned_team | If enabled, players in the unassigned team are ignored. |
| sm_navbot_quota_ignore_spectator_team | If enabled, players in the spectator team are ignored. |
| sm_navbot_quota_unassigned_team_index_override | If greater or equals to 0, overrides the unassigned team index to this convar value. |
| sm_navbot_quota_spectator_team_index_override | If greater or equals to 0, overrides the spectator team index to this convar value. |

The plugin will auto generate a config file in `cfg/sourcemod`.    
Set team index override cvars to **-1** for automatic detection.    
