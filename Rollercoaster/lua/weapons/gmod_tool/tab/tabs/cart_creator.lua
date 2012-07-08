include("weapons/gmod_tool/tab/tab_utils.lua")

local TAB = {}
TAB.ClientConVar = {}
local UNIQUENAME = "cart_creator"

TAB.Name = "Carts"
TAB.UniqueName = UNIQUENAME
TAB.Description = "Create trains that travel along a track."
TAB.Instructions = "Click on an active rollercoaster to set/reset train. Right click to remove all trains from a coaster"
TAB.Icon = "coaster/cart"
TAB.Position = 2

TAB.ClientConVar["minSpeed"] = "0"
TAB.ClientConVar["friction"] = "0.04"
TAB.ClientConVar["allow_weapons"] = "0"
TAB.ClientConVar["cart_amount"] = "1"
TAB.ClientConVar["model"] = "models/XQM/coastertrain2seat.mdl"


list.Set( "CartModels", "2 seater train", "models/xqm/CoasterTrack/train_2.mdl" )
list.Set( "CartModels", "6 seater train front", "models/xqm/coastertrain1.mdl" )
list.Set( "CartModels", "2 seater train front", "models/xqm/coastertrain1seat.mdl" )
list.Set( "CartModels", "fuckyou", "models/props_c17/playground_carousel01.mdl")
list.Set( "CartModels", "4 seater train front", "models/xqm/coastertrain2seat.mdl" )

function TAB:LeftClick( trace, tool )
	local ply   = tool:GetOwner()

	local CartNum 		= GetClientNumber( self, "cart_amount", tool)
	local Friction 		= GetClientNumber( self, "friction", tool)
	local minSpeed 		= GetClientNumber( self, "minSpeed", tool)
	local allowWeapons	= GetClientNumber( self, "allow_weapons", tool)
	local model 		= GetClientInfo( self, "model", tool)
	local spin_override = tool:GetOwner():GetInfoNum("coaster_cart_spin_override")

	//if ( !util.IsValidModel( model ) ) then return false end
	
	local Ent = trace.Entity
	
	if IsValid( Ent ) && ( Ent:GetClass() == "coaster_node" || Ent:GetClass() == "coaster_physmesh" ) then
		if SERVER then 
			local controller = Ent:GetController()

			if IsValid( controller ) then
				print("Creating train for "..tostring(controller))

				local trains = controller:SetTrain( ply, model, CartNum )
				if trains then 
					undo.Create("Coaster Cart")
					undo.SetPlayer( ply )
					undo.SetCustomUndoText("Undone Train")


					for k, train in pairs( trains ) do 
						undo.AddEntity( train )

						train.WheelFriction = Friction
						train.AllowWeapons = allowWeapons==1
						train.MinSpeed = minSpeed

						//Only set it if it's true.
						if spin_override==1 then
							train.Carousel = true
						end
					end
					undo.Finish()
				end
			end
		end
	
		return true
	end

end

function TAB:RightClick( trace, tool )
	local ply   = tool:GetOwner()

	local CartNum = GetClientNumber( self, "cart_amount", tool )
	local Powered = GetClientNumber( self, "powered", tool )
	
	local Ent 		= trace.Entity
	
	if CLIENT then
		print( IsValid( Ent ), Ent:GetClass() )
	end
	if IsValid( Ent ) && (Ent:GetClass() == "coaster_node" || Ent:GetClass() == "coaster_physmesh") then
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

function TAB:Reload( trace, tool )

end

//Called when our tab is closing or the tool was holstered
function TAB:Holster( tool )

end

//Called when our tab being selected
function TAB:Equip( tool )

end

function TAB:Think( tool )

end

function TAB:BuildPanel()
	local panel = vgui.Create("DForm")
	panel:SetName("Cart Options")

	local propSelect = vgui.Create("PropSelect", panel)
	propSelect:SetText("#WheelTool_model")
	propSelect:SetConVar("coaster_supertool_tab_cart_creator_model")
	propSelect:SetText("Carts")

	for k, v in pairs( list.Get("CartModels") ) do
		propSelect:AddModel( v )
	end

	panel:AddItem(propSelect)
	//panel:AddControl( "PropSelect", { Label = "#WheelTool_model", ConVar = "coaster_cart_creator_model", Category = "Carts", Models = list.Get( "CartModels" ) } )

	local cartSlider = vgui.Create("DNumSlider")
	cartSlider:SetText("Number of carts: ")
	cartSlider:SetDecimals( 0 )
	cartSlider:SetMin( 1 )
	cartSlider:SetMax( 8 )
	cartSlider:SetConVar( "coaster_supertool_tab_cart_creator_cart_amount")
	panel:AddItem( cartSlider )
	//panel:AddControl("Slider",   {Label = "Number of carts: ",    Tooltip = "The number of carts on the coaster train",       Type = "Int", Min = "1", Max = "8", Command = "coaster_cart_creator_cart_amount"})

	local MinSpeedSlider = vgui.Create("DNumSlider", panel)
	MinSpeedSlider:SetText("Minimum Speed: ")
	MinSpeedSlider.Tooltip = "Use a minimum speed of 0 to disable."
	MinSpeedSlider:SetDecimals( 3 )
	MinSpeedSlider:SetMin(0)
	MinSpeedSlider:SetMax(100)
	MinSpeedSlider:SetConVar("coaster_supertool_tab_cart_creator_minSpeed")
	MinSpeedSlider:SetValue( 0.0 )
	panel:AddItem( MinSpeedSlider )

	local FrictionSlider = vgui.Create("DNumSlider", panel)
	FrictionSlider:SetText("Frictional Coefficient: ")
	FrictionSlider.Tooltip = "Use a minimum speed of 0 to disable."
	FrictionSlider:SetDecimals( 3 )
	FrictionSlider:SetConVar("coaster_supertool_tab_cart_creator_friction")
	FrictionSlider:SetValue( 0.04 )
	panel:AddItem( FrictionSlider )

	//panel:AddControl("CheckBox", {Label = "Use weapons while in cart", Description = "Aim and shoot weapons while in the cart.", Command = "coaster_cart_creator_allow_weapons"})

	//Commented out for now, feature doesn't exist and it's sounding like it's gonna be a pain in the ass
	/*
	local CheckWeapons = vgui.Create("DCheckBoxLabel", panel )
	CheckWeapons:SetText("Use weapons while in cart")
	CheckWeapons:SetConVar("coaster_supertool_tab_cart_creator_allow_weapons")
	panel:AddItem( CheckWeapons )
	*/


	//panel:AddControl( "Header", { Text = "#Tool_coaster_cart_creator_name", Description = "#Tool_track_cart_desc" }  )

	return panel
end

coastertabmanager.Register( UNIQUENAME, TAB )