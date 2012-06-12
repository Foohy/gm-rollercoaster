//Holds a bunch of handy track generation functions
AddCSLuaFile("util_trackgen.lua")

module( "trackgen", package.seeall )

//Given a spline number, return the segment it's on
function GetSplineSegment(spline, STEPS) //Get the segment of the given spline
	return math.floor( spline / STEPS ) + 2
end