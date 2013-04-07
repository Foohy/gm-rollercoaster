/********************
This file contains enumerations for things like node types, track types, and cart types.
If adding a new type, edit this file
********************/
AddCSLuaFile( "autorun/sh_enums.lua" )
EnumNames = {}

//Node types
COASTER_NODE_NORMAL		= 1
COASTER_NODE_CHAINS		= 2
COASTER_NODE_SPEEDUP	= 3
COASTER_NODE_HOME		= 4
COASTER_NODE_BRAKES		= 5

//Track types
COASTER_TRACK_METAL		= 1
COASTER_TRACK_WOOD 		= 2
COASTER_TRACK_SIMPLE 	= 3
COASTER_TRACK_BM		= 4
COASTER_TRACK_VEKOMA	= 5

//Nice names for above

EnumNames.Nodes = {}
EnumNames.Nodes[COASTER_NODE_NORMAL]	= "Normal Track"
EnumNames.Nodes[COASTER_NODE_CHAINS]	= "Chained Track"
EnumNames.Nodes[COASTER_NODE_SPEEDUP]	= "Speedup/Maglev"
EnumNames.Nodes[COASTER_NODE_HOME]		= "Home Station"
EnumNames.Nodes[COASTER_NODE_BRAKES]	= "Brakes Track"

EnumNames.Tracks = {}
EnumNames.Tracks[COASTER_TRACK_METAL]	= "Metal Track"
EnumNames.Tracks[COASTER_TRACK_WOOD]	= "Wooden Track"
EnumNames.Tracks[COASTER_TRACK_SIMPLE]	= "Simple Track"
EnumNames.Tracks[COASTER_TRACK_BM]		= "B and M Track"
EnumNames.Tracks[COASTER_TRACK_VEKOMA]	= "Vekoma Track"