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
TAB.ClientConVar["startSpeed"] = "4"
TAB.ClientConVar["friction"] = "0.04"
TAB.ClientConVar["allow_weapons"] = "0"
TAB.ClientConVar["cart_amount"] = "1"
TAB.ClientConVar["model"] = "models/XQM/coastertrain2seat.mdl"


list.Set( "CartModels", "2 seater train", "models/xqm/CoasterTrack/train_2.mdl" )
list.Set( "CartModels", "6 seater train front", "models/xqm/coastertrain1.mdl" )
list.Set( "CartModels", "2 seater train front", "models/xqm/coastertrain1seat.mdl" )
list.Set( "CartModels", "fuckyou", "models/props_c17/playground_carousel01.mdl")
list.Set( "CartModels", "4 seater train front", "models/xqm/coastertrain2seat.mdl" )
list.Set( "CartModels", "Spooky Halloween Cart", "models/gmod_tower/halloween_traincar.mdl" )

function TAB:LeftClick( trace, tool )
	local ply   = tool:GetOwner()

	local CartNum 		= GetClientNumber( self, "cart_amount", tool)
	local Friction 		= GetClientNumber( self, "friction", tool)
	local minSpeed 		= GetClientNumber( self, "minSpeed", tool)
	local startSpeed 	= GetClientNumber( self, "startSpeed", tool)
	local allowWeapons	= GetClientNumber( self, "allow_weapons", tool)
	local model 		= GetClientInfo( self, "model", tool)
	local spin_override = tool:GetOwner():GetInfoNum("coaster_cart_spin_override", 0)

	//if ( !util.IsValidModel( model ) ) then return false end
	
	local Ent = trace.Entity
	
	if IsValid( Ent ) && ( Ent:GetClass() == "coaster_node" || Ent:GetClass() == "coaster_physmesh" ) then
		if SERVER then 
			local controller = Ent:GetController()

			if IsValid( controller ) then

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
						train.Velocity = startSpeed

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

	if IsValid( Ent ) && (Ent:GetClass() == "coaster_node" || Ent:GetClass() == "coaster_physmesh") then
		if SERVER then
			local controller = Ent:GetController()
		
			if IsValid( controller ) && SERVER then 
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

//Use the old slider for whole number things
local function NumScratch( panel, strLabel, strConVar, numMin, numMax, numDecimals )
	local left = vgui.Create( "DLabel", panel )
		left:SetText( strLabel )
		left:SetDark( true )
	
	local right = panel:Add( "Panel" )
	
		local entry = right:Add( "DTextEntry" )
			entry:SetConVar( strConVar )
			entry:Dock( FILL )

		local num = right:Add( "DNumberScratch" )
			num:SetMin( tonumber( numMin ) )
			num:SetMax( tonumber( numMax ) )
			num:SetConVar( strConVar )
			num:DockMargin( 4, 0, 0, 0 )
			num:Dock( RIGHT )
	
	panel:AddItem( left, right )
	return left
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
	panel:NumSlider( "Number of carts: ","coaster_supertool_tab_cart_creator_cart_amount", 1, 8, 0)
	panel:ControlHelp("How many carts should be spawned and attached as a single train")

	NumScratch( panel, "Initial speed: ","coaster_supertool_tab_cart_creator_startSpeed", 0.01, 75, 3)

	NumScratch( panel, "Minimum speed: ","coaster_supertool_tab_cart_creator_minSpeed", 0, 75, 3)
	panel:ControlHelp("Never let the cart slow beyond the specified speed. Use a minimum speed of 0 to disable.")

	NumScratch( panel, "Frictional Coefficient: ","coaster_supertool_tab_cart_creator_friction", 0, 1, 3)
	panel:ControlHelp("The frictional coefficient of each cart. Higher = more friction.")

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