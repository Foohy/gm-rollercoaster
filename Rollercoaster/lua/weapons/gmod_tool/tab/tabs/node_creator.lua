include("weapons/gmod_tool/tab/tab_utils.lua")

local TAB = {}
TAB.ClientConVar = {}
local UNIQUENAME = "node_creator"

TAB.Name = "Track"
TAB.UniqueName = UNIQUENAME
TAB.Description = "Create specific track nodes"
TAB.Instructions = "Left click on the world to create a node. Click on an existing node to update it's settings. Right click on any node to loop the track. Reload to retrieve a node's settings."
TAB.Icon = "coaster/track"
TAB.Position = 1

TAB.ClientConVar["id"] = "1"

TAB.ClientConVar["elevation"] = "500"
TAB.ClientConVar["bank"] = "0"
TAB.ClientConVar["tracktype"] = "1"

TAB.ClientConVar["trackchains"] = "0"
TAB.ClientConVar["relativeroll"] = "0"

TAB.GhostModel = Model("models/Combine_Helicopter/helicopter_bomb01.mdl")
TAB.WaitTime	= 0 //Time to wait to make sure the dtvars are updated
TAB.CoolDown 	= 0 //Woah there lil' doggy

function TAB:LeftClick( trace, tool )
	local ply   = tool:GetOwner()
	
	local Elevation = GetClientNumber( self, "elevation", tool )
	local Bank	 	= GetClientNumber( self, "bank", tool )
	local ID 		= GetClientNumber( self, "id", tool )
	local Type 		= GetClientNumber( self, "tracktype", tool )
	local RelRoll 	= GetClientNumber( self, "relativeroll", tool )

	local plyAng	= ply:GetAngles()
			
	local newPos = trace.HitPos + Vector( 0, 0, Elevation )
	local newAng = Angle(0, plyAng.y, 0) + Angle( 0, 0, 0 )
	
	if SERVER then
		if IsValid( trace.Entity ) && trace.Entity:GetClass() == "coaster_node" then //Update an existing node's settings
			//trace.Entity:SetChains( Chains==1 )
			trace.Entity:SetType( Type )
			trace.Entity:SetRelativeRoll( RelRoll==1 )
			trace.Entity:SetRoll( Bank )
			trace.Entity:Invalidate( true )

			local controller = trace.Entity:GetController()

			if controller:Looped() then
				local node = nil
				if trace.Entity == controller.Nodes[2] then
					node = controller.Nodes[#controller.Nodes - 1]
				elseif trace.Entity == controller.Nodes[#controller.Nodes -1 ] then
					node = controller.Nodes[2]
				end

				if IsValid( node ) then
					node:SetType( Type )
					node:SetRelativeRoll( RelRoll==1 )
					node:SetRoll( Bank )
					node:Invalidate( true )
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
					//LastNode:SetChains( Chains==1 )
					LastNode:SetType( Type )
					LastNode:SetRelativeRoll( RelRoll==1 )
					
					VeryLastNode:SetPos( newPos )
					VeryLastNode:SetAngles( newAng )
					//VeryLastNode:SetChains( Chains==1 )
					VeryLastNode:SetType( Type )
					VeryLastNode:SetRelativeRoll( RelRoll==1 )
					
					VeryLastNode.FinalNode = false
				end
				
				//controller.Looped = false
				controller:SetLooped( false )
			else
				local node = CoasterManager.CreateNode( ID, newPos, newAng, Type, ply )
				node:SetRoll( Bank )
				node:SetRelativeRoll( RelRoll==1 )

				if node:IsController() then
					node:SetOwner( ply )
				end
			end

		end
	end

	self.WaitTime = CurTime() + 1
	return true
end

function TAB:RightClick( trace, tool )
	local ply   = tool:GetOwner()
	
	local Elevation = GetClientNumber( self, "elevation", tool )
	local Bank	 	= GetClientNumber( self, "bank", tool )
	local ID 		= GetClientNumber( self, "id", tool )
	local Chains	= GetClientNumber( self, "trackchains", tool )
	local plyAng	= ply:GetAngles()

	if SERVER then
		if IsValid( trace.Entity ) && trace.Entity:GetClass() == "coaster_node" then //Update an existing node's settings
			local ID = trace.Entity.CoasterID
			local Controller = Rollercoasters[ ID ]
			local FirstNode  = Controller:GetFirstNode()
			local SecondToLast = Controller.Nodes[ #Controller.Nodes - 1 ]
			local SecondNode = FirstNode:GetNextNode()
			
			if IsValid( Controller ) && IsValid( Controller:GetFirstNode() ) && !Controller:Looped() then
				local newNode = CoasterManager.CreateNode( ID, FirstNode:GetPos(), FirstNode:GetAngles(), COASTER_NODE_NORMAL, ply )

				local lastNode = Controller.Nodes[ #Controller.Nodes ]
				
				lastNode:SetPos( SecondNode:GetPos() )
				lastNode:SetAngles( SecondNode:GetAngles() )
				Controller:SetPos( SecondToLast:GetPos() )
				Controller:SetAngles( SecondToLast:GetAngles() )

				newNode.FinalNode = true //TODO: Remove the need for this variable
				Controller:SetLooped( true )
				//Controller.Looped = true
				
				print("Looped rollercoaster!")
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
		local ID = trace.Entity.CoasterID
		local Bank = trace.Entity:GetRoll()
		local RelRoll = trace.Entity:GetRelativeRoll()

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

		if IsValid( trace.Entity ) && ( trace.Entity:GetClass() == "coaster_node") && CurTime() > self.WaitTime then

			SelectSingleNode( trace.Entity, Color( 180 - math.random( 0, 120 ), 220 - math.random( 0, 150 ), 255, 255 ))

			local toolText = "Rollercoaster Node"
			if trace.Entity:IsController() then 
				toolText = toolText .. " (Controller)" 
				toolText = toolText .. "\nLooped: " .. tostring( trace.Entity:Looped() )
			end
			toolText = toolText .. "\nType: " .. ( EnumNames.Nodes[ trace.Entity:GetType() ] or "Unknown(?)" )
			toolText = toolText .. "\nRoll: " .. tostring( trace.Entity:GetRoll() )
			//toolText = toolText .. "\nNext Node: " .. tostring( trace.Entity:GetNextNode() )
			AddWorldTip( trace.Entity:EntIndex(), ( toolText ), 0.5, trace.Entity:GetPos(), trace.Entity  )
		else 
			ClearNodeSelection()
		end
	end


	if !IsValid( self.GhostEntity ) then
		MakeGhostEntity( self, self.GhostModel, Vector( 0, 0, 0), Angle( 0, 0, 0) )
	end

	self:UpdateGhostNode( self.GhostEntity, tool )
end


function TAB:UpdateGhostNode( ent, tool )
	local ply = tool:GetOwner()

	if ( !ent || !ent:IsValid() ) then return end

	local tr 		= util.GetPlayerTrace( ply, ply:GetCursorAimVector() )
	local trace 	= util.TraceLine( tr )

	if (!trace.Hit || trace.Entity:IsPlayer() || trace.Entity:GetClass() == "coaster_node" ) then
		ent:SetNoDraw( true )
		return
	end

	local Elevation = GetClientNumber( self, "elevation", tool )
	local newPos = trace.HitPos + Vector( 0, 0, Elevation )
	local newAng = Angle(0, ply:GetAngles().y, 0) + Angle( 0, 0, 0 )

	ent:SetAngles( newAng )
	ent:SetPos( newPos )

	ent:SetNoDraw( false )

end


function TAB:BuildPanel( )
	local panel = vgui.Create("DForm")
	panel:SetName("Node Spawner")

	local IDSlider = vgui.Create("DNumSlider", panel )
	IDSlider:SetText("ID: ")
	IDSlider:SetDecimals( 0 )
	IDSlider:SetMin( 1 )
	IDSlider:SetMax( 8 )
	IDSlider:SetConVar( "coaster_supertool_tab_node_creator_id")
	panel:AddItem( IDSlider )

	local ElevSlider = vgui.Create("DNumSlider", panel)
	ElevSlider:SetText("Elevation: ")
	ElevSlider:SetDecimals( 3 )
	ElevSlider:SetMin(0)
	ElevSlider:SetMax(2000)
	ElevSlider:SetConVar("coaster_supertool_tab_node_creator_elevation")
	panel:AddItem( ElevSlider )

	local BankSlider = vgui.Create("DNumSlider", panel)
	BankSlider:SetText("Roll: ")
	BankSlider:SetDecimals( 2 )
	BankSlider:SetMin( -180 )
	BankSlider:SetMax( 180 )
	BankSlider:SetConVar("coaster_supertool_tab_node_creator_bank")
	panel:AddItem( BankSlider )
	BankSlider:SetValue( 0 )

	//panel:AddControl("Slider",   {Label = "ID: ",    Description = "The ID of the specific rollercoaster (Change the ID if you want to make a seperate coaster)",       Type = "Int", Min = "1", Max = "8", Command = "coaster_track_creator_id"})
	//panel:AddControl("Slider",   {Label = "Elevation: ",    Description = "The height of the track node",       Type = "Float", Min = "0.00", Max = "5000", Command = "coaster_track_creator_elevation"})
	//panel:AddControl("Slider",   {Label = "Bank: ",    Description = "How far to bank at that node",       Type = "Float", Min = "-180.0", Max = "180.0", Command = "coaster_track_creator_bank"})

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
	
	local NoteLabel = vgui.Create("DLabel", panel)
	NoteLabel:SetText("Note: Building the mesh is not realtime.")
	panel:AddItem( NoteLabel )

	local buildBtn = vgui.Create("DButton", panel)
	buildBtn:SetText("Build Mesh")
	buildBtn:SetConsoleCommand("update_mesh")
	panel:AddItem( buildBtn )
	//panel:AddControl("CheckBox", {Label = "Relative Roll: ", Description = "Roll of the cart is relative to the tracks angle (LOOPDY LOOP HEAVEN)", Command = "coaster_track_creator_relativeroll"})

	//panel:AddControl("Button",	 {Label = "BUILD COASTER (CAUTION WEEOOO)", Description = "Build the current rollercoaster with a pretty mesh track. WARNING FREEZES FOR A FEW SECONDS.", Command = "update_mesh"})


	return panel
end


if CLIENT then
	concommand.Add("updatetracks", function(ply, cmd, args ) 

		local Tracks = file.Find("autorun/tracktypes/*", "LUA_PATH")

		PrintTable( Tracks )

	end )
end

coastertabmanager.Register( UNIQUENAME, TAB )