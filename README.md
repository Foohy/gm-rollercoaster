Garry's Mod Lua Rollercoasters
==============================

Lua rollercoaster addon for Garry's Mod adds the ability fully functioning rollercoasters. The curves of the track are using the catmull-rom spline algorithm.


#### Features ####
* Rollecoaster SuperTool, combining all the functions needed for coaster creation into one tool.
* Custom models made by the world acclaimed artist Sunabouzu
* Colorable supports and track
* Saving/Loading of tracks, as well as the ability upload to server
* Change the roll of the track for crazy barrel rolls.
* Realtime preview of generated mesh. Several mesh generation types
* Realistic cart physics - uses friction and energy conservation concepts to calculate speed.
* Hopefully more eventually

#### Perfomance Settings ####
Although coasters have a relatively low perfomance hit when rendering, some things in excess can get a little slow.
All of the following settings can be changed in the 'Settings' tab of the SuperTool.
* coaster_supports 1/0 to toggle the drawing of support beams
* coaster_previews 1/0 to toggle the drawing of track previews
* coaster_motionblur 1/0 to toggle the drawing of motion blur.
* coaster_maxwheels (default: 15 ) maximum number of wheels (breaks, speedups) to be drawing per segment.
* coaster_resolution (default: 15) the 'resolution' of the catmull rom spline for previewing and generated track mesh. Lower = faster generation/better perfmance.

#### Installation ####
Installation is relatively simple. Just extract the Rollercoasters folder into your garrysmod/garrysmod/addons folder.

#### More information ####
* See current status on rollercoasters via the Trello page [located here](https://trello.com/board/rollercoaster/4fd3f7084971ae066211c8ad)
* [Facepunch Thread](http://does_not_exist_yet)