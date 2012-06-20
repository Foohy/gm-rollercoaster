AddCSLuaFile( "weapons/gmod_tool/tab/tab_utils.lua")
AddCSLuaFile( "weapons/gmod_tool/tab/tabmanager.lua")
include("weapons/gmod_tool/tab/tabmanager.lua")
include("weapons/gmod_tool/tab/tab_utils.lua")

TOOL.Category   = "Rollercoaster"
TOOL.Name       = "SUPER TOOL"
TOOL.Command    = nil
TOOL.ConfigName	= nil

TOOL.ClientConVar["selected_tab"] = "1"

function TOOL:LeftClick(trace)
	local ply   = self:GetOwner()
	
	trace = {}
	trace.start  = ply:GetShootPos()
	trace.endpos = trace.start + (ply:GetAimVector() * 99999999)
	trace.filter = ply
	trace = util.TraceLine(trace)

	local class = self:GetCurrentTab()

	if class then
		return class:LeftClick(trace, self)
	end

end

function TOOL:RightClick(trace)
	local ply   = self:GetOwner()
	
	trace = {}
	trace.start  = ply:GetShootPos()
	trace.endpos = trace.start + (ply:GetAimVector() * 99999999)
	trace.filter = ply
	trace = util.TraceLine(trace)

	local class = self:GetCurrentTab()

	if class then
		return class:RightClick(trace, self)
	end
end

function TOOL:Reload(trace)
	local ply   = self:GetOwner()
	
	trace = {}
	trace.start  = ply:GetShootPos()
	trace.endpos = trace.start + (ply:GetAimVector() * 99999999)
	trace.filter = ply
	trace = util.TraceLine(trace)

	local class = self:GetCurrentTab()

	if class then
		return class:Reload(trace, self)
	end
end

function TOOL:Think()
	local class = self:GetCurrentTab()

	if CLIENT then
		local panel = controlpanel.Get("coaster_supertool")
		if panel.Tabs then
			local Sheet = panel.Tabs:GetActiveTab()

			if Sheet.Class && Sheet.Class != class then
				RunConsoleCommand("coaster_supertool_selected_tab", Sheet.Class.UniqueName )
				print("Setting current tab to " .. tostring( Sheet.Class.UniqueName ) )

			end
		end
	end

	// Class neccessary functions
	if self.CurrentClass != class then
		if self.CurrentClass then
			self.CurrentClass:Holster( self )
		end

		if class then
			class:Equip( self )
		end

		self.CurrentClass = class
	end

	//Call their think function
	if class then
		return class:Think( self )
	end
end

function TOOL:Holster()
	local class = self:GetCurrentTab()

	if class then
		return class:Holster( self )
	end
end

function TOOL:GetCurrentTab()
	local Class = coastertabmanager.Get( self:GetClientInfo( "selected_tab") )

	if Class then
		return Class
	end
end

//THANKS ZAAAAAAK
function toSortedTable(T, mbr)
 local v, C, O
 C = {} O = {}
 repeat v = next(T, v) if v then C[v] = T[v] else break end until false

 while next(C, nil) do
  local low = 999999, low_v, x
  repeat x = next(C, x)
  if x and C[x][mbr] < low then low = C[x][mbr] low_v = x end 
  until x == nil

  table.insert(O, C[low_v]) C[low_v] = nil
 end
 return O
end


function TOOL.BuildCPanel(panel)	
	panel:AddControl( "Header", { Text = "#Tool_coaster_supertool_name", Description = "#Tool_coaster_supertool_desc" }  )

	local PropertySheet = vgui.Create( "DPropertySheet", panel )
	PropertySheet:SetPos( 5, 30 )
	PropertySheet:SetSize( 340, 600 )

	local FixedTable = toSortedTable( coastertabmanager.List, "Position")

	for k, v in pairs(FixedTable) do
		local panel = v:BuildPanel()
		RegisterTabPanel( panel, v.UniqueName )
		local sheet = PropertySheet:AddSheet( v.Name, panel, v.Icon, false, false, v.Description )	
		sheet.Tab.Class = v
	end

	panel:AddItem( PropertySheet )
	panel.Tabs = PropertySheet
	 
	//local SheetItemOne = vgui.Create( "DCheckBoxLabel" )
	//SheetItemOne:SetText( "Use Props?" )
	//SheetItemOne:SetValue( 1 )
	//SheetItemOne:SizeToContents()
	 
	//local SheetItemTwo = vgui.Create( "DCheckBoxLabel" , CategoryContentTwo )
	//SheetItemTwo:SetText( "Use SENTs?" )
	//SheetItemTwo:SetValue( 1 )
	//SheetItemTwo:SizeToContents()

	//PropertySheet:AddSheet( "Some Menu", SheetItemOne, "gui/silkicons/user", false, false, "WOW It's a text box!!!" )
	//PropertySheet:AddSheet( "Super Menu", SheetItemTwo, "gui/silkicons/group", false, false, "Can I haz meh cheezburger now?" )

end



if CLIENT then

	language.Add( "Tool_coaster_supertool_name", "MEGA SUPER TOOL ABLJBLASDJBASOGOF08ASOXCSALDJBASJB" )
	language.Add( "Tool_coaster_supertool_desc", "IT DOES EVERYTHING" )
	language.Add( "Tool_coaster_supertool_0", "EEVVEERRYYYTHIIINNGGGGGGGGGGGG" )

end

