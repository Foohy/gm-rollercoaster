ENT.Type 			= "anim"
ENT.Base 			= "base_anim"
ENT.PrintName		= "Rollercoaster Node"
ENT.Author			= "Foohy"
ENT.Information		= "A node for a rollercoaster"
ENT.Category		= "Foohy"

ENT.Spawnable		= false
ENT.AdminSpawnable	= false
ENT.Editable 		= true

ENT.Material 		= "hunter/myplastic"
--[[
edits by miterdoo:

+added launch segment
	any launch segment will be assigned a launch key that the user can set in
	the tool, right below the node roll value. when the segment is not launching,
	or is in "idle mode," then it acts as a home station, but carts cannot move
	once they've stopped. when the segment is launching, when the player taps/
	presses the launch key for the segment, the segment acts as a speedup track
	but with a acceleration specified by the player that placed the segment.
	these tracks cannot be placed if a launch key is not set yet.
*FIXED node roll being assigned to the next node placed rather than the one
	currently being placed.

]]

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "IsController")
	self:NetworkVar("Bool", 1, "Looped")
	self:NetworkVar("Entity", 0, "NextNode")
	self:NetworkVar("Entity", 1, "Controller")
	self:NetworkVar("Int", 0, "NodeType", { KeyName = "type", Edit = { type = "Enum", enums = EnumNames.Nodes, min = 1, max = 4, order = 2 } } )
	self:NetworkVar("Int", 1, "TrackType", { KeyName = "tracktype", Edit = { type = "Enum", enums = EnumNames.Tracks, min = 1, max = 4, order = 3 } })
	self:NetworkVar("Int", 2, "LaunchKey")
	self:NetworkVar("String",1,"LaunchKeyString")
	self:NetworkVar("Float", 0, "Roll")
	self:NetworkVar("Float",1,"LaunchSpeed")
	self:NetworkVar("Vector", 0, "TrackColor", { KeyName = "trackcolor", Edit = { type = "VectorColor", order = 4 } } )
	self:NetworkVar("String", 0, "CoasterID") --The string is STEAMID_ID (ex: STEAM_0:1:18712009_3 )

	self:DTVar("Int", 2, "Order") -- Backwards compatability 
	self:DTVar("Int", 3, "NumCoasterNodes") -- Backwards compatability
end

-- The clients should always know about the nodes
function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end


-- Utility function to create a color from a normalized vector
function ENT:GetActualTrackColor()
	local color = self:GetTrackColor()
	return Color( color.x * 255, color.y * 255, color.z * 255 )
end