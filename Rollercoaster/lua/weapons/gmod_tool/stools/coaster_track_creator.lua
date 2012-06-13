TOOL.Category   = "Rollercoaster"
TOOL.Name       = "Coaster Track Creator"
TOOL.Command    = nil
TOOL.ConfigName	= nil

TOOL.ClientConVar["id"] = "1"

TOOL.ClientConVar["elevation"] = "500"
TOOL.ClientConVar["bank"] = "0"
TOOL.ClientConVar["tracktype"] = "1"
//CreateConVar( "coaster_track_creator_tracktype", "1")

TOOL.ClientConVar["trackchains"] = "0"
TOOL.ClientConVar["relativeroll"] = "0"

TOOL.GhostModel = Model("models/Combine_Helicopter/helicopter_bomb01.mdl")
TOOL.WaitTime	= 0 //Time to wait to make sure the dtvars are updated
TOOL.CoolDown 	= 0 //Woah there lil' doggy

coaster_track_creator_HoverEnts = {}

function TOOL:LeftClick(trace)
	//if CurTime() < self.CoolDown then return end
	//self.CoolDown = CurTime() + .25

	local ply   = self:GetOwner()
	
	trace = {}
	trace.start  = ply:GetShootPos()
	trace.endpos = trace.start + (ply:GetAimVector() * 99999999)
	trace.filter = ply
	trace = util.TraceLine(trace)
	
	local Elevation = self:GetClientNumber("elevation")
	local Bank	 	= self:GetClientNumber("bank")
	local ID 		= self:GetClientNumber("id")
	local Type 		= self:GetClientNumber("tracktype")
	local RelRoll 	= self:GetClientNumber("relativeroll")

	local plyAng	= self:GetOwner():GetAngles()
			
	local newPos = trace.HitPos + Vector( 0, 0, Elevation )
	local newAng = Angle(0, plyAng.y, 0) + Angle( 0, 0, 0 )
	
	if SERVER then
		if IsValid( trace.Entity ) && trace.Entity:GetClass() == "coaster_node" then //Update an existing node's settings
			//trace.Entity:SetChains( Chains==1 )
			trace.Entity:SetType( Type )
			trace.Entity:SetRelativeRoll( RelRoll==1 )
			trace.Entity:SetRoll( Bank )
			trace.Entity:Invalidate( true )
			
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
				local node = CoasterManager.CreateNode( ID, newPos, newAng, Type )
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

if CLIENT then
concommand.Add("updatetracks", function(ply, cmd, args ) 

//function UpdateTrackTypes()

	local Tracks = file.Find("autorun/tracktypes/*", "LUA_PATH")

	PrintTable( Tracks )

//end
	end )
end

function TOOL:RightClick(trace)
	local ply   = self:GetOwner()
	
	trace = {}
	trace.start  = ply:GetShootPos()
	trace.endpos = trace.start + (ply:GetAimVector() * 99999999)
	trace.filter = ply
	trace = util.TraceLine(trace)
	
	local Elevation = self:GetClientNumber("elevation")
	local Bank	 	= self:GetClientNumber("bank")
	local ID 		= self:GetClientNumber("id")
	local Chains	= self:GetClientNumber("trackchains")
	local plyAng	= self:GetOwner():GetAngles()

	if SERVER then
		if IsValid( trace.Entity ) && trace.Entity:GetClass() == "coaster_node" then //Update an existing node's settings
			local ID = trace.Entity.CoasterID
			local Controller = Rollercoasters[ ID ]
			local FirstNode  = Controller:GetFirstNode()
			local SecondToLast = Controller.Nodes[ #Controller.Nodes - 1 ]
			local SecondNode = FirstNode:GetNextNode()
			
			if IsValid( Controller ) && IsValid( Controller:GetFirstNode() ) then
				local newNode = CoasterManager.CreateNode( ID, FirstNode:GetPos(), FirstNode:GetAngles(), COASTER_NODE_NORMAL )

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

function TOOL:Reload(trace)

end

function TOOL:Holster()
	if CLIENT then
		ClearNodeSelection()
	end

	 if IsValid( self.GhostEntity ) && ( SERVER || !SinglePlayer() ) then 
		self.GhostEntity:SetNoDraw( true )
	end
end

function TOOL:Think()
	if CLIENT then
		local Elevation = self:GetClientNumber("elevation")
		local Slope 	= self:GetClientNumber("slope")
		local plyAng	= self:GetOwner():GetAngles()
			
		local ply   = self:GetOwner()

		if IsValid( self.GhostEntity ) && ( SERVER || !SinglePlayer() ) then 
			self.GhostEntity:SetNoDraw( false )
		end
			
		trace = {}
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

			if IsValid( self.GhostEntity ) && ( SERVER || !SinglePlayer() ) then 
				self.GhostEntity:SetNoDraw( true )
			end
		else 
			ClearNodeSelection()
		end

			
		if !IsValid( self.GhostEntity ) then
			self:MakeGhostEntity( self.GhostModel, newPos, newAng )
		end
		if SERVER || !SinglePlayer() then 
			self.GhostEntity:SetPos( newPos )
			self.GhostEntity:SetAngles( newAng )
		end
	end
end

function TOOL:ValidTrace(trace)

end

function TOOL.BuildCPanel(panel)	
	panel:AddControl("Slider",   {Label = "ID: ",    Description = "The ID of the specific rollercoaster (Change the ID if you want to make a seperate coaster)",       Type = "Int", Min = "1", Max = "8", Command = "coaster_track_creator_id"})
	panel:AddControl("Slider",   {Label = "Elevation: ",    Description = "The height of the track node",       Type = "Float", Min = "0.00", Max = "5000", Command = "coaster_track_creator_elevation"})
	panel:AddControl("Slider",   {Label = "Bank: ",    Description = "How far to bank at that node",       Type = "Float", Min = "-180.0", Max = "180.0", Command = "coaster_track_creator_bank"})

	local ComboBox = vgui.Create("DComboBox", panel)
	//Create some nice choices
	if EnumNames.Nodes && #EnumNames.Nodes > 0 then
		for k, v in pairs( EnumNames.Nodes ) do
			ComboBox:AddChoice(v)
		end

		ComboBox:ChooseOptionID( COASTER_NODE_NORMAL )
		RunConsoleCommand("coaster_track_creator_tracktype", COASTER_NODE_NORMAL ) //Default to normal
	end

	ComboBox.OnSelect = function(index, value, data)
		RunConsoleCommand("coaster_track_creator_tracktype" , tostring( value ) )
	end

	panel:AddItem( ComboBox )

	panel:AddControl("CheckBox", {Label = "Relative Roll: ", Description = "Roll of the cart is relative to the tracks angle (LOOPDY LOOP HEAVEN)", Command = "coaster_track_creator_relativeroll"})
	panel:AddControl("Button",	 {Label = "BUILD COASTER (CAUTION WEEOOO)", Description = "Build the current rollercoaster with a pretty mesh track. WARNING FREEZES FOR A FEW SECONDS.", Command = "update_mesh"})

	panel:AddControl( "Header", { Text = "#Tool_coaster_track_creator_name", Description = "#Tool_track_creator_desc" }  )
end

if CLIENT then

	language.Add( "Tool_coaster_track_creator_name", "Rollercoaster Track Layout Creator" )
	language.Add( "Tool_coaster_track_creator_desc", "Create the track nodes to a rollercoaster!" )
	language.Add( "Tool_coaster_track_creator_0", "Left click on the world to create a node. Click on an existing node to update it's settings. Right click on any node to loop the track." )

end

