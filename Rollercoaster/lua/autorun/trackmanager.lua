
module( "trackmanager", package.seeall )


List = {}

local function IsLua( name )
	return string.sub( name, -4 ) == ".lua"
end

local function ValidName( name )
	return name != "." && name != ".." && name != ".svn"
end


function LoadClasses()
	local fileList = file.Find("autorun/tracktypes/*", "LUA" )
	local baseclass = "autorun/tracktypes/sh_track_base.lua"
	-- Load the base class
	if SERVER then
		AddCSLuaFile( baseclass)
		include( baseclass )
	else
		include( baseclass )
	end

	for _, name in pairs( fileList ) do
	
		local loadName = "tracktypes/" .. name
		
		if !IsLua( loadName ) then continue end
		if !ValidName( loadName ) then continue end 
		
		if SERVER then
			AddCSLuaFile( loadName )
			include( loadName )
		else
			include( loadName )
		end
		
	end

end

function Register( name, class )
	class.LastItem = 0
	List[ name ] = class
end

function GetStatic( name )
	return List[ name ]
end

function Get( name )
	return List[ name ]:Create()
end

function GetRandom()
	return table.Random( List )
end

trackmanager.LoadClasses()
