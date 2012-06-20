TOOL.Category   = "Rollercoaster"
TOOL.Name       = "Track Remover"
TOOL.Command    = nil
TOOL.ConfigName	= nil

//TOOL.ClientConVar["r"] = "255"
//TOOL.ClientConVar["g"] = "255"
//TOOL.ClientConVar["b"] = "255"

function TOOL:LeftClick(trace)
	local ply   = self:GetOwner()
	
	trace = {}
	trace.start  = ply:GetShootPos()
	trace.endpos = trace.start + (ply:GetAimVector() * 99999999)
	trace.filter = ply
	trace = util.TraceLine(trace)
	
	local Ent = trace.Entity
	
	if IsValid( Ent ) && Ent:GetClass() == "coaster_node" then
		if SERVER then 
			local controller = Ent:GetController()

			if IsValid( controller ) && controller:GetOwner() == ply then
				controller:Remove()
			else
				print("You do not own that coaster!")
			end
		end
	
		return true
	end

end

function TOOL:RightClick(trace)

end

function TOOL:Reload(trace)

end

function TOOL:Think()
	if CLIENT then
		local ply = LocalPlayer()

		trace = {}
		trace.start  = ply:GetShootPos()
		trace.endpos = trace.start + (ply:GetAimVector() * 999999)
		trace.filter = ply
		trace = util.TraceLine(trace)

		if IsValid( trace.Entity ) && ( trace.Entity:GetClass() == "coaster_node") then
			local controller = trace.Entity:GetController()
			if IsValid( controller ) then
				local color = Color( 255, 280 - math.random( 0, 260 ), 180 - math.random( 0, 150 ), 255 )

				SelectAllNodes( controller, color )
			end
		else 
			ClearNodeSelection()
		end

	end
end

function TOOL:Holster()
	if CLIENT then
		ClearNodeSelection()
	end
end

function TOOL.BuildCPanel(panel)	
	panel:AddControl( "Header", { Text = "#Tool_coaster_remover_name", Description = "#Tool_coaster_remover_desc" }  )
end

if CLIENT then

	language.Add( "Tool_coaster_remover_name", "Track Remover" )
	language.Add( "Tool_coaster_remover_desc", "Delete your entire track" )
	language.Add( "Tool_coaster_remover_0", "Click on any node of a track to remove the entire thing" )

end

