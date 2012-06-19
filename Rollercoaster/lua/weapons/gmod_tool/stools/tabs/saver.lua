local TAB = {}
TAB.ClientConVar = {}
local UNIQUENAME = "save"

TAB.Name = "Save"
TAB.UniqueName = UNIQUENAME
TAB.Description = "Save and load tracks "
TAB.Icon = "coaster/save"
TAB.Position = 5 //The position in the series of tabs


function TAB:LeftClick( trace, tool )

end

function TAB:RightClick( trace, tool )

end

function TAB:Reload( trace )

end

//Called when our tab is closing or the tool was holstered
function TAB:Holster()

end

//Called when our tab being selected
function TAB:Equip( tool )

end

function TAB:Think( tool )

end

function UpdateConColors()

end

function TAB:BuildPanel( )
	local panel = vgui.Create("DForm")
	panel:SetText("OVERWRITE ME")
	panel.Label = "whwowhwho"

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