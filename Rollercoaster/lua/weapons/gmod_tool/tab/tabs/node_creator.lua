include("weapons/gmod_tool/tab/tab_utils.lua")

local TAB = {}
TAB.ClientConVar = {}
local UNIQUENAME = "node_creator"

TAB.Name 			= "Track"
TAB.UniqueName 		= UNIQUENAME
TAB.Description 	= "Create specific track nodes"
TAB.Instructions 	= "Left click on the world to create a node. Click on an existing node to update it's settings. Right click on any node to loop the track."
TAB.Icon 			= "coaster/track"
TAB.Position 		= 1

TAB.ClientConVar["id"] = "1"

TAB.ClientConVar["elevation"] = "150"
TAB.ClientConVar["bank"] = "0"
TAB.ClientConVar["tracktype"] = "1"

TAB.ClientConVar["prev_nodeheight"] = "0"
TAB.ClientConVar["trackchains"] = "0"
TAB.ClientConVar["relativeroll"] = "0"

TAB.GhostModel = Model("models/Combine_Helicopter/helicopter_bomb01.mdl")
TAB.WaitTime	= 0 //Time to wait to make sure the dtvars are updated

function TAB:LeftClick( trace, tool )
	local ply   = tool:GetOwner()
	
	local Elevation = GetClientNumber( self, "elevation", tool )
	local Bank	 	= GetClientNumber( self, "bank", tool )
	local ID 		= ply:SteamID() .. "_" ..  GetClientInfo( self, "id", tool )
	local Type 		= GetClientNumber( self, "tracktype", tool )
	local RelRoll 	= GetClientNumber( self, "relativeroll", tool ) == 1
	local matchZ 	= GetClientNumber( self, "prev_nodeheight", tool ) == 1
	local plyAng	= ply:GetAngles()
			
	local newPos = trace.HitPos + Vector( 0, 0, math.Clamp( Elevation, 0, 10000000 ) )
	local newAng = Angle(0, plyAng.y, 0) + Angle( 0, 0, 0 )
	
	if SERVER then
		local Node = GetActualNodeEntity( trace.Entity )
		if IsValid( Node ) && Node:GetClass() == "coaster_node" then //Update an existing node's settings
			local ShouldInvalidate = Node:GetRoll() != Bank
			Node:SetType( Type )
			Node:SetRelativeRoll( RelRoll )
			Node:SetRoll( Bank )

			if ShouldInvalidate then
				Node:Invalidate( true )
			end

			local controller = Node:GetController()

			if controller.Looped && controller:Looped() then
				local prevnode = nil
				if Node == controller.Nodes[2] then
					prevnode = controller.Nodes[#controller.Nodes - 1]
				elseif Node == controller.Nodes[#controller.Nodes -1 ] then
					prevnode = controller.Nodes[2]
				end

				if IsValid( prevnode ) then
					prevnode:SetType( Type )
					prevnode:SetRelativeRoll( RelRoll )
					prevnode:SetRoll( Bank )
					if ShouldInvalidate then
						prevnode:Invalidate( true )
					end
				end
			end
			
		else //If we didn't click on an existing node, create a new one		
			//If the coaster is looped, unloop it
			local controller = Rollercoasters[ID]
			
			if IsValid( controller ) && controller:Looped() then
				local LastNode = controller.Nodes[ #controller.Nodes - 1 ]
				local VeryLastNode = controller.Nodes[ #controller.Nodes ]
				if IsValid( LastNode ) && IsValid( VeryLastNode ) && VeryLastNode.FinalNode then
					LastNode:SetPos( newPos )
					LastNode:SetAngles( newAng )
					LastNode:SetType( Type )
					//LastNode:SetRelativeRoll( RelRoll)
					
					VeryLastNode:SetPos( newPos )
					VeryLastNode:SetAngles( newAng )
					VeryLastNode:SetType( Type )
					//VeryLastNode:SetRelativeRoll( RelRoll )
					
					VeryLastNode.FinalNode = false
				end
				
				//controller.Looped = false
				controller:SetLooped( false )
			else //The coaster is NOT looped, so create a new node normally
				if matchZ && IsValid( controller ) then
					local VeryLastNode = controller.Nodes[ #controller.Nodes ]
					if IsValid( VeryLastNode ) then
						newPos.z = VeryLastNode:GetPos().z + Elevation
					end
				end
				local node = CoasterManager.CreateNode( ID, newPos, newAng, Type, ply )
				if !IsValid( node ) then return end

				node:SetRoll( Bank )
				//node:SetRelativeRoll( RelRoll )

				//Set the previous node to use the current values, to make things have more sense
				local controller = Rollercoasters[ID]
				if #controller.Nodes > 2 then
					local LastNode = controller.Nodes[ #controller.Nodes - 1 ]
					if IsValid( LastNode ) then
						LastNode:SetPos( newPos )
						LastNode:SetAngles( newAng )
						LastNode:SetType( Type )
					end
				end
				

				if node:IsController() then
					node:SetOwner( ply )
				end
			end

		end
	end

	self.WaitTime = CurTime() + 1
	return true
end

//Loop the track so carts don't fall off
function TAB:RightClick( trace, tool )
	local ply   = tool:GetOwner()
	
	local Elevation = GetClientNumber( self, "elevation", tool )
	local Bank	 	= GetClientNumber( self, "bank", tool )
	local ID 		= ply:SteamID() .. "_" .. tostring( GetClientNumber( self, "id", tool ) )
	local Chains	= GetClientNumber( self, "trackchains", tool )
	local plyAng	= ply:GetAngles()

	if SERVER then
		local Node = GetActualNodeEntity( trace.Entity )
		if IsValid( Node ) && Node:GetClass() == "coaster_node" then //Update an existing node's settings
			local Cur_ID = Node:GetCoasterID()
			local Controller = Rollercoasters[ Cur_ID ]
			local FirstNode  = Controller:GetFirstNode()
			local SecondToLast = Controller.Nodes[ #Controller.Nodes - 1 ]
			
			if IsValid( Controller ) && IsValid( FirstNode ) && !Controller:Looped() then
				local newNode = CoasterManager.CreateNode( Cur_ID, FirstNode:GetPos(), FirstNode:GetAngles(), COASTER_NODE_NORMAL, ply )
				local lastNode = Controller.Nodes[ #Controller.Nodes ]
				local SecondNode = FirstNode:GetNextNode()
				if !IsValid( newNode ) || !IsValid( lastNode ) || !IsValid(SecondNode) || !IsValid(SecondToLast) then return end
				
				lastNode:SetPos( SecondNode:GetPos() )
				lastNode:SetAngles( SecondNode:GetAngles() )
				Controller:SetPos( SecondToLast:GetPos() )
				Controller:SetAngles( SecondToLast:GetAngles() )

				newNode.FinalNode = true //TODO: Remove the need for this variable
				Controller:SetLooped( true )

				//Now that it's looped, make sure all nodes are in their correct place		
				for _, v in pairs( Controller.Nodes ) do
					if IsValid( v ) then v:UpdateMagicPositions() end
				end

				//Delay so the new node is initialized
				timer.Simple( 0.2, function() 
					Controller:UpdateServerSpline()
				end )

			end
		end
	end
	
	return true
end

//TODO: Make this get the facing node's settings
function TAB:Reload( trace, tool )
	local ply   = tool:GetOwner()

	if IsValid( trace.Entity ) && trace.Entity:GetClass() == "coaster_node" then //Update an existing node's settings

		//Info gathering time
		local type = trace.Entity:GetType()
		local ID = trace.Entity:GetCoasterID()
		local Bank = trace.Entity:GetRoll()
		//local RelRoll = trace.Entity:GetRelativeRoll()

	end
end

//Called when our tab is closing or the tool was holstered
function TAB:Holster( tool )
	if CLIENT then
		ClearNodeSelection()
	end

	if IsValid( self.GhostEntity ) then
		self.GhostEntity:SetNoDraw( true )
	end
end

//Called when our tab being selected
function TAB:Equip( tool )

end

function TAB:Think( tool )
	if CLIENT then
		local ply   = tool:GetOwner()

		local Elevation = GetClientNumber( self, "elevation", tool )
		local Slope 	= GetClientNumber( self, "slope", tool )
		local plyAng	= ply:GetAngles()

		local trace = {}
		trace.start  = ply:GetShootPos()
		trace.endpos = trace.start + (ply:GetAimVector() * 99999999)
		trace.filter = ply
		trace = util.TraceLine(trace)

				
		local newPos = trace.HitPos + Vector( 0, 0, Elevation )
		local newAng = Angle(0, plyAng.y, 0) + Angle( Slope, 0, 0 )
		
		//Make the tooltip

		if IsValid( trace.Entity ) && ( ( trace.Entity:GetClass() == "coaster_node") || trace.Entity:GetClass() == "coaster_physmesh") && CurTime() > self.WaitTime then

			//Get the node, depending on if we are the physics mesh or the controller
			local Node = GetActualNodeEntity( trace.Entity )

			if !IsValid( Node ) then return end

			//Highlight the node
			SelectSingleNode( Node, Color( 180 - math.random( 0, 120 ), 220 - math.random( 0, 150 ), 255, 255 ))

			local toolText = "Rollercoaster Node"
			if Node.GetCoasterID then
				toolText = toolText .. " (" .. Node:GetCoasterID() .. ")"
			end
			if Node.IsController && Node:IsController() then 
				toolText = toolText .. " (Controller)" 
				toolText = toolText .. "\nLooped: " .. tostring( Node:Looped() )
			end
			if Node.GetType && Node.GetRoll then
				toolText = toolText .. "\nType: " .. ( EnumNames.Nodes[ Node:GetType() ] or "Unknown(?)" )
				toolText = toolText .. "\nRoll: " .. tostring( Node:GetRoll() )
			end

			//toolText = toolText .. "\nNext Node: " .. tostring( trace.Entity:GetNextNode() )
			AddWorldTip( Node:EntIndex(), ( toolText ), 0.5, Node:GetPos(), Node )
		else 
			ClearNodeSelection()
		end
	end

	if !IsValid( self.GhostEntity ) then
		MakeGhostEntity( self, self.GhostModel, Vector( 0, 0, 0), Angle( 0, 0, 0) )
	end

	self:UpdateGhostNode( tool )
end


//A helper function to return the node whether we are that same node or a physics mesh
function GetActualNodeEntity( entity )
	local Node = nil
	if entity:GetClass() == "coaster_node" then 
		Node = entity
	else 
		if entity.GetController && IsValid( entity:GetController() ) && entity:GetController().GetCoasterID then
			Node = entity:GetController().Nodes[ entity.Segment ]
		end
	end

	return Node
end

//TODO: include in rollercoaster table
function GetControllerFromID( id )
	for _, v in pairs( ents.FindByClass("coaster_node")) do
		if v.IsController && v:IsController() && v:GetCoasterID() == id then return v end
	end

end


function TAB:UpdateGhostNode( tool )
	if (self.GhostEntity == nil) then return end
	if (!self.GhostEntity:IsValid()) then self.GhostEntity = nil return end

	local ply = tool:GetOwner()

	if ( !self.GhostEntity || !self.GhostEntity:IsValid() ) then return end

	local tr 		= util.GetPlayerTrace( ply )
	local trace 	= util.TraceLine( tr )

	if (!trace.Hit || trace.Entity:IsPlayer() || trace.Entity:GetClass() == "coaster_node" || trace.Entity:GetClass() == "coaster_physmesh" ) then
		self.GhostEntity:SetNoDraw( true )
		return
	end

	local Elevation = GetClientNumber( self, "elevation", tool )
	local ID = ply:SteamID() .. "_" .. tostring( GetClientNumber( self, "id", tool ) )
	local matchZ = GetClientNumber( self, "prev_nodeheight", tool ) == 1
	local newPos = trace.HitPos + Vector( 0, 0, math.Clamp( Elevation, 0, 10000000 ) )
	local newAng = Angle(0, ply:GetAngles().y, 0) + Angle( 0, 0, 0 )

	//Set the height of the last node if it's checked
	local controller = GetControllerFromID( ID )
	if matchZ && IsValid( controller ) then
		local LastNode = controller.Nodes[ #controller.Nodes ]
		if IsValid( LastNode ) then
			newPos.z = LastNode:GetPos().z + Elevation
		end
	end

	self.GhostEntity:SetAngles( newAng )
	self.GhostEntity:SetPos( newPos )

	self.GhostEntity:SetNoDraw( false )

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

function TAB:BuildPanel( )
	local panel = vgui.Create("DForm")
	panel:SetName("Node Spawner")

	panel:NumSlider( "Rollercoaster ID: ","coaster_supertool_tab_node_creator_id", 1, 8, 0)


	local ComboBox = vgui.Create("DComboBox", panel)
	//Create some nice choices
	if EnumNames.Nodes && #EnumNames.Nodes > 0 then
		for k, v in pairs( EnumNames.Nodes ) do
			ComboBox:AddChoice(v)
		end

		ComboBox:ChooseOptionID( COASTER_NODE_NORMAL )
		RunConsoleCommand("coaster_supertool_tab_node_creator_tracktype", COASTER_NODE_NORMAL ) //Default to normal
	end

	ComboBox.OnSelect = function(index, value, data)
		RunConsoleCommand("coaster_supertool_tab_node_creator_tracktype" , tostring( value ) )
	end
	panel:AddItem( ComboBox )

	local Seperator = vgui.Create("DLabel", panel)
	Seperator:SetText("______________________________________________")
	panel:AddItem( Seperator )

	//The elevation slider
	NumScratch( panel, "Node Elevation: ","coaster_supertool_tab_node_creator_elevation", -2000, 2000, 3)

	//And the thing to make it easier
	local easyelev = vgui.Create("DEasyButtons", self)
	easyelev.ConVar = "coaster_supertool_tab_node_creator_elevation"
	easyelev.Offset = 50
	panel:AddItem( easyelev )

	//Set to the height of the previous node?
	panel:CheckBox( "Relative to previous node's elevation", "coaster_supertool_tab_node_creator_prev_nodeheight" )

	local Seperator = vgui.Create("DLabel", panel)
	Seperator:SetText("______________________________________________")
	panel:AddItem( Seperator )

	NumScratch( panel, "Node Roll: ","coaster_supertool_tab_node_creator_bank", -180.01, 180, 2)
	RunConsoleCommand("coaster_supertool_tab_node_creator_bank", 0 ) //Default to 0

	local easyroll = vgui.Create("DEasyButtons", self)
	easyroll.ConVar = "coaster_supertool_tab_node_creator_bank"
	easyroll.Offset = 45

	panel:AddItem( easyroll )

	//panel:AddControl("Slider",   {Label = "ID: ",    Description = "The ID of the specific rollercoaster (Change the ID if you want to make a seperate coaster)",       Type = "Int", Min = "1", Max = "8", Command = "coaster_track_creator_id"})
	//panel:AddControl("Slider",   {Label = "Elevation: ",    Description = "The height of the track node",       Type = "Float", Min = "0.00", Max = "5000", Command = "coaster_track_creator_elevation"})
	//panel:AddControl("Slider",   {Label = "Bank: ",    Description = "How far to bank at that node",       Type = "Float", Min = "-180.0", Max = "180.0", Command = "coaster_track_creator_bank"})



	//panel:AddControl("CheckBox", {Label = "Relative Roll: ", Description = "Roll of the cart is relative to the tracks angle (LOOPDY LOOP HEAVEN)", Command = "coaster_track_creator_relativeroll"})

	//panel:AddControl("Button",	 {Label = "BUILD COASTER (CAUTION WEEOOO)", Description = "Build the current rollercoaster with a pretty mesh track. WARNING FREEZES FOR A FEW SECONDS.", Command = "coaster_update_mesh"})


	return panel
end

coastertabmanager.Register( UNIQUENAME, TAB )