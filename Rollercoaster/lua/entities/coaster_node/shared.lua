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

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "IsController")
	self:NetworkVar("Bool", 1, "Looped")
	self:NetworkVar("Entity", 0, "NextNode")
	self:NetworkVar("Entity", 1, "Controller")
	self:NetworkVar("Int", 0, "NodeType", { KeyName = "type", Edit = { type = "Enum", enums = EnumNames.Nodes, min = 1, max = 4, order = 2 } } )
	self:NetworkVar("Int", 1, "TrackType", { KeyName = "tracktype", Edit = { type = "Enum", enums = EnumNames.Tracks, min = 1, max = 4, order = 3 } })
	self:NetworkVar("Float", 0, "Roll")
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