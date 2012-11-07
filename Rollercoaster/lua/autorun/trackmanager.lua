
module( "trackmanager", package.seeall )

//ClassesFolder = string.sub( GM.Folder, 11 ) .. "/gamemode/classes/"

List = {}

local function IsLua( name )
	return string.sub( name, -4 ) == ".lua"
end

local function ValidName( name )
	return name != "." && name != ".." && name != ".svn"
end


function LoadClasses()
	local fileList = file.Find("autorun/tracktypes/*", "LUA" )
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

function Get( name )
	return List[ name ]
end

function GetRandom()
	return table.Random( List )
end

trackmanager.LoadClasses()
