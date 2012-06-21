include("weapons/gmod_tool/tab/tab_utils.lua")

local TAB = {}
TAB.ClientConVar = {}
local UNIQUENAME = "copy_me"

TAB.Name = "You Should Copy Me"
TAB.UniqueName = UNIQUENAME
TAB.Description = "Create new tooltypes by copying this file as an example"
TAB.Instructions = "Basically what I just said up there ^"
TAB.Icon = "coaster/settings"
TAB.Position = 6 //The position in the series of tabs

TAB.ClientConVar["testconvar"] = "255"


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
	panel:SetName("OVERWRITE ME")

	return panel
end

//coastertabmanager.Register( UNIQUENAME, TAB )