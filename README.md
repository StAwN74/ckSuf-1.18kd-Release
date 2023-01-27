﻿# ckSurf-1.18kd-Release 🌍
  *!Being back soon (jan 2023)!*  
  Last seen version of a great plugin, server crash fixed. No need to fully unload plugin on regular maps.
  Available for any server tickrate.  
  Only 1 bonus bot for maps with several bonus stages, to finally and completely break the memory leak.  
  Find me / Discuss here: https://forums.alliedmods.net/member.php?u=107052. More info in the included Readme.  
  Last updated summer 2020, being back in jan 2023. I just fixed bots, hud, and updated smlib, and will share soon.  
  Taking no credit except the fixing part of a good ol' car, see below:  
  - Replays related crashs fixed. Bots' trails removed like in other forks, for performance.
  - Player & admin commands related issues fixed. Some rcon commands (with client 0) were fuzzy.
  - Weapons and bots management reviewed to avoid errors & maps crashs.
  - Hooks/events updated, plugin now supports any kind of map & bots don't mess up with mp_restartgame.
  - Timer handles and client indexes fixed. As for the commands, it was leading to weird situations.

Notes: Now you have colored start speed, a fixed goto command by Headline (see changelog).  
       sm_clear console warning when starting a run is normal and harmless, it's a fix for a checkpoint plugin I needed.  

Thanks to ZZK community and Freak.exe for testing, and support. Thx to Elzi / jonitaikaponi for the original plugin.  
Thanks to Headline for his sm_goto:  https://forums.alliedmods.net/showthread.php?p=2323724  
My other plugins: http://www.sourcemod.net/plugins.php?cat=0&mod=-1&title=&author=St00ne&description=&search=1

# Install 🏄
  - Copy cfg/server_example.cfg content to your server.cfg, then upload all files. Keep your own cleaner extension version if it works, as I will not update it.
  - Create a database entry in addons/sourcemod/configs/databases.cfg like so (you should set your user & password):
  https://nsa40.casimages.com/img/2019/10/10/191010010823736378.png
  - Start the server. Using -tickrate 102.4 parameter in command start line of a csgo surf server is recommended to avoid ramp glitch.
  Also consider using start /AboveNormal like said here: https://support.steampowered.com/kb_article.php?ref=5386-HMJI-5162

# Changelog 👺
  - 06/07/20: Fixed PlayReplay error log.  
  
  - 20/06/20: Fixed bot custom skin if ck_custom_models was 1. Reset the 0.1 second timer. Code cleaned a little.  
  
  - 09-13/06/20: Fixed bots quota, plugin doesn't mix their IDs anymore. Reaload map if you have any quota pb.  
  Fixed lag on player quit/death!!  
  
  - 08/06/20: Added 'Estimated Start Speed' in player chat. Fixed the timer after going to spectator team (mb).  
  
  - 02/06/20: Fixed ragdoll removal, a lil' translation mistyping, & round end/match start on regular maps.  
  Added a raw "FakeClientCommandEx sm_clear" to prevent cheats whith another checkpoint plugin, adding a harmless console warning (sry though).  
  Discovered you should not try mp_restartgame on surf_summer (laggy).  
  
  - 16/01/20: Fixed weapon buy on regular maps like de_dust2,  and 'checkSpawns' log error. Plugin uses maps configs (cfg/sourcemod/ckSurf/map_types/) for respawn and round end. ck_autorespawn and ck_round_end are thus obsolete.  
  
  - Note: In plugins/disabled, there's a ckSurf_slh_rev smx file (ckSurf_slnh_rev for non discord users).  
    You can use the this version instead of the regular one, if you have properly set sv_hibernate_when_empty 0 in server.cfg and in server's launch command parameters.  
    It will never check and never change your hibernation status to write data in your database, which I recommend.
