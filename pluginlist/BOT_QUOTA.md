# NavBot Simple Bot Quota System

This plugin adds a simple bot quota system.    

## Usage

The `sm_navbot_quota_enabled` ConVar enables/disables the bot quota system. Disabling the bot quota does not kick bots.    
The `sm_navbot_quota` ConVar sets the quota target. If set to less than or equals to zero, all bots are removed from the server.    
The `sm_navbot_quota_mode` ConVar sets the quota mode. See table below for more information.    

## Quota Modes

| Mode | Description |
|:---:|:---:|
| Normal | The number of bots in the server matches the quota target. |
| Fill | Fill the server until humans + bots matches the quota target. Bots are kicked to make room for humans. |
| Match | The number of bots matches the number of humans multiplied by the quota target. |

## Additional Options

| ConVar Name | Description |
|:---:|:---:|
| sm_navbot_quota_ignore_others | When enabled, non NavBot bots are not counted as humans. Useful in gamemodes like TF2's MvM. |
| sm_navbot_quota_only_kick_dead | When enabled, only dead bots are kicked. |
| sm_navbot_quota_think_rate | Sets the frequency in seconds the bot quota system "thinks". |

## Commands

| Command Name | Description | Default Admin Flag |
|:---:|:---:|:---:|
| sm_navbot_quota_list_players | Utility command that lists players and what kind they are (navbot, bot or human). | generic |
