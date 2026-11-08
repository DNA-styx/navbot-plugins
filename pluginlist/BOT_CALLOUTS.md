# NavBot Callouts

Plugin implement basic callouts for bots.    
They report any enemy they encounter in team chat using `say_team`.    
Bots send messages in the server's language (if translation is available for it).    

## Compatibility

The game/mod must support the `say_team` client command.    

## ConVars

| Name | Description |
|:---:|:---:|
| sm_navbot_callouts_enabled | Controls if callouts are enabled. |
| sm_navbot_callouts_per_bot_cooldown | Per bot callout cooldown in seconds. Bots won't send another callout until at least this many seconds have passed. |
| sm_navbot_callouts_per_team_cooldown | Per team callout cooldown in seconds. Bots from the same team won't send another callout until at least this many seconds have passed. |
| sm_navbot_callouts_team_only | Only bots from this team index can send callouts. Negative values to allow all teams to send callouts. |
| sm_navbot_callouts_players_only | If enabled, bots only reports enemy players. |
