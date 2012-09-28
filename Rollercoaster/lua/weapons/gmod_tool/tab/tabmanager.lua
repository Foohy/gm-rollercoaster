
module( "coastertabmanager", package.seeall )


List = {}

local function IsLua( name )
	return string.sub( name, -4 ) == ".lua"
end

local function ValidName( name )
	return name != "." && name != ".." && name != ".svn"
end


function LoadClasses()
	local fileList = file.Find("weapons/gmod_tool/tab/tabs/*", "LUA" )
	
	for _, name in pairs( fileList ) do
	
		local loadName = "weapons/gmod_tool/tab/tabs/" .. name
		
		if !IsLua( loadName ) then continue end
		if !ValidName( loadName ) then continue end 
		
		if SERVER then
			AddCSLuaFile( loadName )
		end

		include( loadName )
		
	end

end

function Register( name, class )
	class.LastItem = 0
	List[ name ] = class

	CreateConVars( class )
end

function CreateConVars( tab )
	if !tab.ClientConVar then return end

	for cvar, default in pairs( tab.ClientConVar ) do
       	if CLIENT then
			CreateClientConVar( "coaster_supertool_tab_" .. tab.UniqueName .. "_" .. cvar, default, true, true )
		end

	end

	//Not implemented yet, but might as well have it
	if SERVER then
		CreateConVar( "tab_allow_" .. tab.UniqueName, 1, FCVAR_NOTIFY )
	end

end

function Get( name )
	return List[ name ]
end

coastertabmanager.LoadClasses()
