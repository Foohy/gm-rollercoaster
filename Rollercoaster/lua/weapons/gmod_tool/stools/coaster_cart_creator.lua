TOOL.Category   = "Rollercoaster"
TOOL.Name       = "Coaster Cart Creator"
TOOL.Command    = nil
TOOL.ConfigName	= nil

TOOL.ClientConVar["powered"] = "0"
TOOL.ClientConVar["cart_amount"] = "1"

function TOOL:LeftClick(trace)
	local ply   = self:GetOwner()
	
	trace = {}
	trace.start  = ply:GetShootPos()
	trace.endpos = trace.start + (ply:GetAimVector() * 99999999)
	trace.filter = ply
	trace = util.TraceLine(trace)

	local CartNum = self:GetClientNumber("cart_amount")
	local Powered = self:GetClientNumber("powered")
	
	local Ent = trace.Entity
	
	if IsValid( Ent ) && Ent:GetClass() == "coaster_node" then
		if SERVER then 
			local controller = Ent:GetController()

			if IsValid( controller ) then
				print("Creating train for "..tostring(controller))
				controller:SetTrain( ply, CartNum, Powered==1 )
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
				print("Removing train for "..tostring(controller))
				controller:ClearTrains()
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

	panel:AddControl( "Header", { Text = "#Tool_coaster_cart_creator_name", Description = "#Tool_track_cart_desc" }  )
end

if CLIENT then

	language.Add( "Tool_coaster_cart_creator_name", "Cart Creator" )
	language.Add( "Tool_coaster_cart_creator_desc", "Create the rollercoaster train." )
	language.Add( "Tool_coaster_cart_creator_0", "Click on an active rollercoaster to set/reset train. Right click to remove all trains from a coaster" )

end

