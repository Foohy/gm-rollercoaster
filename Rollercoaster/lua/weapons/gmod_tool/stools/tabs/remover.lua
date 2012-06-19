local TAB = {}
TAB.ClientConVar = {}
local UNIQUENAME = "remover"

TAB.Name = "Remove"
TAB.UniqueName = UNIQUENAME
TAB.Description = "Remove entire rollercoasters"
TAB.Icon = "coaster/remover"
TAB.Position = 4

function TAB:LeftClick( trace, tool )
	local ply   = tool:GetOwner()
	
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

function TAB:RightClick( trace, tool )

end

function TAB:Reload( trace )

end

//Called when our tab is closing or the tool was holstered
function TAB:Holster()
	if CLIENT then
		ClearNodeSelection()
	end
end

//Called when our tab being selected
function TAB:Equip( tool )

end

function TAB:Think( tool )
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

function UpdateConColors()

end

function TAB:BuildPanel( )
	local panel = vgui.Create("DForm")
	panel:SetText("Coaster Remover")

	return panel
end

/////////////////
//Util Functions
/////////////////

function TAB:GetClientNumber( convar, tool)
	return tool:GetOwner():GetInfoNum("coaster_supertool_tab_" .. self.UniqueName .. "_" .. convar, 0 )
end

function TAB:GetClientInfo(convar, tool)
	return tool:GetOwner():GetInfo("coaster_supertool_tab_" .. self.UniqueName .. "_" .. convar )
end

coastertabmanager.Register( UNIQUENAME, TAB )