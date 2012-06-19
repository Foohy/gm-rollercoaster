TOOL.Category   = "Rollercoaster"
TOOL.Name       = "Coaster Cart Creator"
TOOL.Command    = nil
TOOL.ConfigName	= nil

TOOL.ClientConVar["minSpeed"] = "0"
TOOL.ClientConVar["friction"] = "0.04"
TOOL.ClientConVar["allow_weapons"] = "0"
TOOL.ClientConVar["cart_amount"] = "1"
TOOL.ClientConVar["model"] = "models/XQM/coastertrain2seat.mdl"

function TOOL:LeftClick(trace)
	local ply   = self:GetOwner()
	
	trace = {}
	trace.start  = ply:GetShootPos()
	trace.endpos = trace.start + (ply:GetAimVector() * 99999999)
	trace.filter = ply
	trace = util.TraceLine(trace)

	local CartNum 		= self:GetClientNumber("cart_amount")
	local Friction 		= self:GetClientNumber("friction")
	local minSpeed 		= self:GetClientNumber("minSpeed")
	local allowWeapons	= self:GetClientNumber("allow_weapons")
	local model 		= self:GetClientInfo("model")

	//if ( !util.IsValidModel( model ) ) then return false end
	
	local Ent = trace.Entity
	
	if IsValid( Ent ) && Ent:GetClass() == "coaster_node" then
		if SERVER then 
			local controller = Ent:GetController()

			if IsValid( controller ) then
				print("Creating train for "..tostring(controller))
				print( tostring( model ) )
				local train = controller:SetTrain( ply, model, CartNum )
				train.WheelFriction = Friction
				train.AllowWeapons = allowWeapons==1
				train.MinSpeed = minSpeed
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
	/*
	local NumCartsSlider = vgui.Create("DNumSlider", panel)
	NumCartsSlider:SetText("Number of carts: ")
	NumCartsSlider.Type = "Int"
	NumCartsSlider.Min = "1"
	NumCartsSlider.Max = "8"
	NumCartsSlider.Command = "coaster_cart_creator_cart_amount"
	panel:AddItem( NumCartsSlider )
	*/

	panel:AddControl( "PropSelect", { Label = "#WheelTool_model", ConVar = "coaster_cart_creator_model", Category = "Carts", Models = list.Get( "CartModels" ) } )

	panel:AddControl("Slider",   {Label = "Number of carts: ",    Tooltip = "The number of carts on the coaster train",       Type = "Int", Min = "1", Max = "8", Command = "coaster_cart_creator_cart_amount"})

	local MinSpeedSlider = vgui.Create("DNumSlider", panel)
	MinSpeedSlider:SetText("Minimum Speed: ")
	MinSpeedSlider.Tooltip = "Use a minimum speed of 0 to disable."
	MinSpeedSlider.Type = "Float"
	MinSpeedSlider:SetMin(0)
	MinSpeedSlider:SetMax(100)
	MinSpeedSlider:SetConVar("coaster_cart_creator_minSpeed")
	MinSpeedSlider:SetValue( 0.0 )
	panel:AddItem( MinSpeedSlider )

	local FrictionSlider = vgui.Create("DNumSlider", panel)
	FrictionSlider:SetText("Frictional Coefficient: ")
	FrictionSlider.Tooltip = "Use a minimum speed of 0 to disable."
	FrictionSlider.Type = "Float"
	FrictionSlider.Min = "0"
	FrictionSlider.Max = "1"
	FrictionSlider:SetConVar("coaster_cart_creator_friction")
	FrictionSlider:SetValue( 0.04 )
	panel:AddItem( FrictionSlider )

	panel:AddControl("CheckBox", {Label = "Use weapons while in cart", Description = "Aim and shoot weapons while in the cart.", Command = "coaster_cart_creator_allow_weapons"})
	//panel:AddControl("Slider",   {Label = "Minimum Speed (0: ",    Description = "The number of carts on the coaster train",       Type = "Int", Min = "1", Max = "8", Command = "coaster_cart_creator_cart_amount"})

	panel:AddControl( "Header", { Text = "#Tool_coaster_cart_creator_name", Description = "#Tool_track_cart_desc" }  )
end

//list.Set( "CartModels", "models/XQM/CoasterTrack/train_2.mdl", { } )
//list.Set( "CartModels", "models/XQM/coastertrain1.mdl", { } )
//list.Set( "CartModels", "models/XQM/coastertrain1seat.mdl", {} )
//list.Set( "CartModels", "models/props_c17/playground_carousel01.mdl", {} )
//list.Set( "CartModels" , "models/XQM/coastertrain2seat.mdl", {})

if CLIENT then

	language.Add( "Tool_coaster_cart_creator_name", "Cart Creator" )
	language.Add( "Tool_coaster_cart_creator_desc", "Create the rollercoaster train." )
	language.Add( "Tool_coaster_cart_creator_0", "Click on an active rollercoaster to set/reset train. Right click to remove all trains from a coaster" )

end

