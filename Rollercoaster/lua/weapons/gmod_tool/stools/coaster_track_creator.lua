TOOL.Category   = "Rollercoaster"
TOOL.Name       = "Coaster Track Creator"
TOOL.Command    = nil
TOOL.ConfigName	= nil

TOOL.ClientConVar["id"] = "1"

TOOL.ClientConVar["elevation"] = "500"
TOOL.ClientConVar["bank"] = "0"

TOOL.ClientConVar["trackchains"] = "0"
TOOL.ClientConVar["relativeroll"] = "0"

TOOL.GhostModel = Model("models/Combine_Helicopter/helicopter_bomb01.mdl")
TOOL.WaitTime	= 0 //Time to wait to make sure the dtvars are updated

function TOOL:LeftClick(trace)
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
	local RelRoll 	= self:GetClientNumber("relativeroll")
	local plyAng	= self:GetOwner():GetAngles()
			
	local newPos = trace.HitPos + Vector( 0, 0, Elevation )
	local newAng = Angle(0, plyAng.y, 0) + Angle( 0, 0, 0 )
	
	if SERVER then
		if IsValid( trace.Entity ) && trace.Entity:GetClass() == "coaster_node" then //Update an existing node's settings
			trace.Entity:SetChains( Chains==1 )
			trace.Entity:SetRelativeRoll( RelRoll==1 )
			trace.Entity:SetRoll( Bank )
			
		else //If we didn't click on an existing node, create a new one		
			//If the coaster is looped, unloop it
			local controller = Rollercoasters[ID]
			
			if IsValid( controller ) && controller:Looped() then
			
				local LastNode = controller.Nodes[ #controller.Nodes - 1 ]
				local VeryLastNode = controller.Nodes[ #controller.Nodes ]
				if IsValid( LastNode ) && IsValid( VeryLastNode ) && VeryLastNode.FinalNode then
					LastNode:SetPos( newPos )
					LastNode:SetAngles( newAng )
					LastNode:SetChains( Chains==1 )
					LastNode:SetRelativeRoll( RelRoll==1 )
					
					VeryLastNode:SetPos( newPos )
					VeryLastNode:SetAngles( newAng )
					VeryLastNode:SetChains( Chains==1 )
					VeryLastNode:SetRelativeRoll( RelRoll==1 )
					
					VeryLastNode.FinalNode = false
				end
				
				//controller.Looped = false
				controller:SetLooped( false )
			else
				local node = CoasterManager.CreateNode( ID, newPos, newAng, Chains==1 )
				node:SetRoll( Bank )
				node:SetRelativeRoll( RelRoll==1 )
			end

		end
	end
	self.WaitTime = CurTime() + 1
	return true
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
				local newNode = CoasterManager.CreateNode( ID, FirstNode:GetPos(), FirstNode:GetAngles(), false )
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

function TOOL:Think()
	if CLIENT then
		local Elevation = self:GetClientNumber("elevation")
		local Slope 	= self:GetClientNumber("slope")
		local plyAng	= self:GetOwner():GetAngles()
			
		local ply   = self:GetOwner()
			
		trace = {}
		trace.start  = ply:GetShootPos()
		trace.endpos = trace.start + (ply:GetAimVector() * 99999999)
		trace.filter = ply
		trace = util.TraceLine(trace)
				
		local newPos = trace.HitPos + Vector( 0, 0, Elevation )
		local newAng = Angle(0, plyAng.y, 0) + Angle( Slope, 0, 0 )
		
		//Make the tooltip

		if IsValid( trace.Entity ) && ( trace.Entity:GetClass() == "coaster_node") && CurTime() > self.WaitTime then
			local toolText = "Rollercoaster Node"
			if trace.Entity:IsController() then 
				toolText = toolText .. " (Controller)" 
			end
			toolText = toolText .. "\nChained: " .. tostring(trace.Entity:HasChains()) 
			toolText = toolText .. "\nself: " .. tostring( trace.Entity )
			toolText = toolText .. "\nNext Node: " .. tostring( trace.Entity:GetNextNode() )
			AddWorldTip( trace.Entity:EntIndex(), ( toolText ), 0.5, trace.Entity:GetPos(), trace.Entity  )
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
	panel:AddControl("CheckBox", {Label = "Chains: ", Description = "Should the track have chains to push the cart up the hill?", Command = "coaster_track_creator_trackchains"})
	panel:AddControl("CheckBox", {Label = "Relative Roll: ", Description = "Roll of the cart is relative to the tracks angle (LOOPDY LOOP HEAVEN)", Command = "coaster_track_creator_relativeroll"})
	panel:AddControl("Button",	 {Label = "BUILD COASTER (CAUTION WEEOOO)", Description = "Build the current rollercoaster with a pretty mesh track. WARNING FREEZES FOR A FEW SECONDS.", Command = "update_mesh"})

	panel:AddControl( "Header", { Text = "#Tool_coaster_track_creator_name", Description = "#Tool_track_creator_desc" }  )
end

if CLIENT then

	language.Add( "Tool_coaster_track_creator_name", "Rollercoaster Track Layout Creator" )
	language.Add( "Tool_coaster_track_creator_desc", "Create the track nodes to a rollercoaster!" )
	language.Add( "Tool_coaster_track_creator_0", "Left click on the world to create a node. Click on an existing node to update it's settings. Right click on any node to loop the track." )

end

