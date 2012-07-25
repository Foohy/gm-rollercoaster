include("weapons/gmod_tool/tab/tab_utils.lua")
local TAB = {}
TAB.ClientConVar = {}
local UNIQUENAME = "remover"

TAB.Name = ""
TAB.Name2 = "Remover" //Name for the non-tab stuff
TAB.UniqueName = UNIQUENAME
TAB.Description = "Remove entire rollercoasters"
TAB.Instructions = "Click on any node of a track to remove the entire thing"
TAB.Icon = "coaster/remover"
TAB.Position = 5

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
	panel:SetName("Coaster Remover")

	panel:Help("Remove entire rollercoasters at a time. Unless you are an admin, you can only remove your own tracks.")

	return panel
end

coastertabmanager.Register( UNIQUENAME, TAB )