Garry's Mod Lua Rollercoasters
==============================

Lua rollercoaster addon for Garry's Mod adds the ability fully functioning rollercoasters. The curves of the track are using the catmull-rom spline algorithm.


#### Features ####
* Fully physical rollercoaster trains with multiple carts per train.
* Rollecoaster SuperTool, combining all the functions needed for coaster creation into one tool.
* Colorable supports and tracks.
* Saving/Loading of tracks, as well as the ability upload to server
* Change the roll of the track for deep turns and crazy barrel rolls.
* Realtime preview of generated mesh. Several mesh generation types and system for creating more.
* Realistic cart physics - uses newton's theories of physics to accurately calculate speed and friction.
* Carts that fly off the track have a chance of hopping back on another track.
* Generated mesh has per-vertex lighting, instead of lighting based around a single point.

#### Fine-tuning ####
Serverside/admin commands and convars.
* coaster_maxcarts (default: 16) The maximum number of *carts* per player that they can spawn.
* coaster_maxnodes (default: 70) The maximum number of *nodes* per player that they can spawn.
* coaster_cart_explosive_damage 1/0 Toggle whether the cart should explode in a massive fireball.
* coaster_cart_cooldown 1/0 Toggle the cooldown of vomitting and screaming in carts.
* coaster_physmesh_resolution (default: 10) The resolution of the serverside physics mesh of the tracks. Higher resolution is more precise, but laggier.
* coaster_downloadtoclients 1/0 Define if the clients should download the resources for rollercoaster.

All of the following settings can be changed in the 'Settings' tab of the SuperTool.
* coaster_supports 1/0 Toggle the drawing of support beams
* coaster_mesh_previews 1/0 Toggle the drawing of track previews
* coaster_motionblur 1/0 Toggle the drawing of motion blur.
* coaster_maxwheels (default: 15 ) The maximum number of wheels (breaks, speedups) to be drawing per segment.
* coaster_mesh_resolution (default: 15) The 'resolution' of the catmull rom spline for previewed and generated track mesh. Lower = faster generation/better performance.
* coaster_mesh_stepspercycle (default: 4) How many 'steps' of track generation to perform per frame. Higher is laggier, but it is built faster
* coaster_mesh_maxvertices (default: 50000) The maximum number of vertices per model. As the mesh is built, it is split into multiple models as it hits this limit.
* coaster_mesh_drawoutdatedmesh 1/0 If the mesh is currently being rebuilt, should the old mesh be drawn?
* coaster_mesh_drawunfinishedmesh 1/0 If the mesh is currently being built, should the unfinished mesh be drawn?

#### Installation ####
Installation is relatively simple. Just extract the Rollercoasters folder into your garrysmod/garrysmod/addons folder.

#### More information ####
* See current status on rollercoasters via the Trello page [located here](https://trello.com/board/rollercoaster/4fd3f7084971ae066211c8ad)
* [Facepunch Thread](http://www.facepunch.com/showthread.php?t=1200443)
* [Foohy.net](http://foohy.net/)