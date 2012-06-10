TOOL.Category   = "Rollercoaster"
TOOL.Name       = "Coaster Cart Creator"
TOOL.Command    = nil
TOOL.ConfigName	= nil

TOOL.ClientConVar["r"] = "255"
TOOL.ClientConVar["g"] = "255"
TOOL.ClientConVar["b"] = "255"

function TOOL:LeftClick(trace)
	local ply   = self:GetOwner()
	
	trace = {}
	trace.start  = ply:GetShootPos()
	trace.endpos = trace.start + (ply:GetAimVector() * 99999999)
	trace.filter = ply
	trace = util.TraceLine(trace)

	local CartNum = self:GetClientNumber("cart_amount")
	local Powered = self:GetClientNumber("powered")
	local r = tonumber(self:GetClientNumber("r")) or 255
	local g = tonumber(self:GetClientNumber("g")) or 255
	local b = tonumber(self:GetClientNumber("b")) or 255
	
	local Ent = trace.Entity
	
	if IsValid( Ent ) && Ent:GetClass() == "coaster_node" then
		if SERVER then 
			local controller = Ent:GetController()

			if IsValid( controller ) then
				print("Editing settings for "..tostring(controller.CoasterID))
				controller:SetTrackColor(r,g,b)
			end
		end
	
		return true
	end

end

function TOOL:RightClick(trace)
	local ply   = self:GetOwner()
	
	trace = {}
	trace.start  = ply:GetShootPos()
	trace.endpos = trace.start + (ply:GetAimVector() * 99999999)
	trace.filter = ply
	trace = util.TraceLine(trace)

	local CartNum = self:GetClientNumber("cart_amount")
	local Powered = self:GetClientNumber("powered")
	
	local Ent 		= trace.Entity
	
	if IsValid( Ent ) && Ent:GetClass() == "coaster_node" then
		if SERVER then
			local controller = Ent:GetController()
		
			if IsValid( controller ) && SERVER then 
				print("Doing nothing for "..tostring(controller.CoasterID))
				//controller:ClearTrains()
			end
		end
		
		return true
	end
end

function TOOL:Reload(trace)

end

function TOOL:Think()

end

function TOOL:ValidTrace(trace)

end

function TOOL.BuildCPanel(panel)	
	panel:AddControl("Slider",   {Label = "Number of carts: ",    Description = "The number of carts on the coaster train",       Type = "Int", Min = "1", Max = "8", Command = "coaster_cart_creator_cart_amount"})
	panel:AddControl("CheckBox", {Label = "Minimum Speed: ", Description = "Should the cart ever stop (Behaves just like as if the cart was permanently on chains)", Command = "coaster_cart_creator_powered"})
	panel:AddControl("Color", { Label = "Track Color", Multiplier = 255, ShowAlpha = false, Red = "coaster_settings_r", Green = "coaster_settings_g", Blue = "coaster_settings_b"})

	panel:AddControl( "Header", { Text = "#Tool_coaster_cart_creator_name", Description = "#Tool_track_cart_desc" }  )
end

if CLIENT then

	language.Add( "Tool_coaster_settings_name", "Coaster Settings" )
	language.Add( "Tool_coaster_settings_desc", "Change track-wide settings" )
	language.Add( "Tool_coaster_settings_0", "Click on any node of a rollercoaster to update its settings" )

end

