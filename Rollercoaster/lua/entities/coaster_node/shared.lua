ENT.Type 			= "anim"
ENT.Base 			= "base_anim"
ENT.PrintName		= "Roller coaster Node"
ENT.Author			= "Foohy"
ENT.Information		= "A node for a rollercoaster"
ENT.Category		= "Foohy"

ENT.Spawnable		= false
ENT.AdminSpawnable	= false

ENT.Model			= Model( "models/hunter/misc/sphere075x075.mdl" )
ENT.Material 		= "hunter/myplastic"

function ENT:SetupDataTables()
	self:DTVar("Bool", 0, "IsController")
	self:DTVar("Bool", 1, "RelativeRoll")
	self:DTVar("Bool", 2, "Looped")
	self:DTVar("Entity", 0, "NextNode")
	self:DTVar("Entity", 1, "Controller")
	self:DTVar("Int", 0, "Type")
	self:DTVar("Int", 1, "TrackType")
	self:DTVar("Float", 0, "Roll")
	self:DTVar("Vector", 0, "TrackColor")
	self:DTVar("Vector", 1, "SupportColor")

	//self:SetNetworkedString( "CoasterID", "")//The string is STEAMID_ID (ex: STEAM_0:1:18712009_3 )
	self:DTVar("String", 0, "CoasterID") 
end

//Function to get if we are being driven with garry's new drive system
function ENT:IsBeingDriven()
	for _, v in pairs( player.GetAll() ) do
		if v:GetViewEntity() == self then return true end
	end

	return false
end

function ENT:SetIsController(bController)
	self.dt.IsController = bController
end

function ENT:IsController()
	return self.dt.IsController or false
end

function ENT:SetController( cont )
	self.dt.Controller = cont
end

function ENT:GetController()
	return self.dt.Controller
end

function ENT:SetRelativeRoll(bRelRoll)
	self.dt.RelativeRoll = bRelRoll
end

function ENT:RelativeRoll()
	return self.dt.RelativeRoll or false
end

function ENT:SetLooped(looped)
	self.dt.Looped = looped
end

function ENT:Looped()
	return self.dt.Looped or false
end

function ENT:SetNextNode(node)
	self.dt.NextNode = node
end

function ENT:GetNextNode()
	return self.dt.NextNode
end

function ENT:SetType(type)
	self.dt.Type = type
end

function ENT:GetType()
	return self.dt.Type or COASTER_NODE_NORMAL
end

function ENT:SetTrackType(type)
	self.dt.TrackType = type
end

function ENT:GetTrackType()
	return self.dt.TrackType or COASTER_TRACK_METAL
end

function ENT:SetCoasterID( id )
	self.dt.CoasterID = id
	//self:SetNetworkedString("CoasterID", id )
end

function ENT:GetCoasterID()
	return self.dt.CoasterID;
	//return self:GetNetworkedString("CoasterID")
end

function ENT:SetRoll(roll) //Not to be confused with CLuaParticle.SetRoll()
	self.dt.Roll = roll
end

function ENT:GetRoll() //Not to be confused with CLuaParticle.GetRoll()
	return self.dt.Roll or 0
end

function ENT:SetTrackColor(r,g,b) 
	self.dt.TrackColor = Vector( r, g, b )
end

function ENT:GetTrackColor() 
	return Color( self.dt.TrackColor.x, self.dt.TrackColor.y, self.dt.TrackColor.z )
end

function ENT:SetSupportColor(r,g,b) 
	self.dt.SupportColor = Vector( r, g, b )
end

function ENT:GetSupportColor() 
	return self.dt.SupportColor.x, self.dt.SupportColor.y, self.dt.SupportColor.z 
end