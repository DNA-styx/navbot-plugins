# NavBot Nav Mesh Manager

A plugin for managing navigation meshes. This plugin can download and/or auto generate a nav mesh for maps that doesn't have one.    
A config file will be auto generated in `cfg/sourcemod`.    
All features of this plugin are **OPT-IN**! You have to enable them in the config file.    

## ConVars

- sm_nb_navmesh_manager_auto_download: Enables automatic downloading of nav mesh files.
- sm_nb_navmesh_manager_download_url: Base HTTP mirror URL. (Do not add a forward slash at the end of the url)
- sm_nb_navmesh_manager_auto_gen: Enables automatic generation of nav mesh files.

## Requirements

Requires the [SourceMod REST in Pawn Extension](https://github.com/ErikMinekus/sm-ripext) for download nav mesh files.

## NavMesh HTTP Mirror Format

The plugin uses the following format to search for files:    
If the base url is `navbot.example.com` and the current mod folder is `tf` and the current map is `ctf_2fort`.    
The final download URL becomes `navbot.example.com/tf/ctf_2fort.smnav`.    
The plugin also searches for place name database files.    
