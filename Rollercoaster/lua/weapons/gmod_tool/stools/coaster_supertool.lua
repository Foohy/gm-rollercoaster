AddCSLuaFile( "weapons/gmod_tool/tab/tab_utils.lua")
AddCSLuaFile( "weapons/gmod_tool/tab/tabmanager.lua")
include("weapons/gmod_tool/tab/tabmanager.lua")
include("weapons/gmod_tool/tab/tab_utils.lua")

TOOL.Category   = "Rollercoaster"
TOOL.Name       = "Rollercoaster SuperTool"
TOOL.Command    = nil
TOOL.ConfigName	= nil

TOOL.ClientConVar["selected_tab"] = "1"

function TOOL:LeftClick(trace)
	local class = self:GetCurrentTab()

	if class then
		return class:LeftClick(trace, self)
	end

end

function TOOL:RightClick(trace)

	local class = self:GetCurrentTab()

	if class then
		return class:RightClick(trace, self)
	end
end

function TOOL:Reload(trace)

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

			//Update the header HUD
			if CLIENT then
				//print(class.Name)
				//language.remove("Tool_coaster_supertool_name")
				//language.Add( "Tool_coaster_supertool_name", class.Name )
				//language.Add( "Tool_coaster_supertool_desc", class.Description )
			end
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

//Yoinked from garry's tool HUD rendering code.
function TOOL:DrawHUD()
	if ( !GetConVar("gmod_drawhelp"):GetBool() ) then return end
       
	local class = self:GetCurrentTab()

	//Default names in case the class didn't define them
	local Name = "None"
	local Desc = "None"
	local Instructions = "None"

	if class then
		if class.Name then Name = class.Name end
		if class.Name == "" && class.Name2 then Name = class.Name2 end //quickfix
		if class.Description then Desc = class.Description end
		if class.Instructions then Instructions = class.Instructions end
	end
   
    local x, y = 50, 40
    local w, h = 0, 0
   
    local TextTable = {}
    local QuadTable = {}
   
    TextTable.font = "GModToolName"
    TextTable.color = Color( 240, 240, 240, 255 )
    TextTable.pos = { x, y }
    TextTable.text = Name
   
    w, h = draw.TextShadow( TextTable, 3 )
    y = y + h

    TextTable.font = "GModToolSubtitle"
    TextTable.pos = { x, y }
    TextTable.text = Desc
    w, h = draw.TextShadow( TextTable, 2 )

    y = y + h + 11
   
    TextTable.font = "GModToolHelp"
    TextTable.pos = { x + 24, y  }
    TextTable.text = Instructions
    w, h = draw.TextShadow( TextTable, 2 )
end

local function DrawScrollingText( text, y, texwide )

	local w, h = surface.GetTextSize( text )
	w = w + 64

	local x = math.fmod( CurTime() * 400, w ) * -1;

	while ( x < texwide ) do

		surface.SetTextColor( 0, 0, 0, 255 )
		surface.SetTextPos( x + 3, y + 3 )
		surface.DrawText( text )
          
		surface.SetTextColor( 255, 255, 255, 255 )
		surface.SetTextPos( x, y )
		surface.DrawText( text )
       
		x = x + w
           
	end
end

function TOOL:DrawToolScreen( TEX_SIZE )
	local class = self:GetCurrentTab()
	local text = "None"
	if class && class.Name then text = class.Name end
	if class.Name == "" && class.Name2 then text = class.Name2 end //quickfix

	surface.SetFont("GModToolScreen")
	DrawScrollingText( text, 64, TEX_SIZE )
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
	//panel:AddControl( "Header", { Text = "#Tool_coaster_supertool_name", Description = "#Tool_coaster_supertool_desc" }  )

	local PropertySheet = vgui.Create( "DPropertySheet", panel )
	PropertySheet:SetPos( 0, 0 )
	PropertySheet:SetSize( 360, 560 ) //340, 600

	local FixedTable = toSortedTable( coastertabmanager.List, "Position")

	for k, v in pairs(FixedTable) do
		local panel = v:BuildPanel()
		RegisterTabPanel( panel, v.UniqueName )
		
		local sheet = PropertySheet:AddSheet( v.Name, panel, v.Icon, false, false, v.Description )	
		sheet.Tab.Class = v
	end

	panel:AddItem( PropertySheet )
	panel.Tabs = PropertySheet

	panel:Button( "Build Clientside Mesh", "update_mesh")
	panel:ControlHelp( "Note: Building the mesh is not realtime. You WILL experience a temporary freeze when building the mesh." )

end



if CLIENT then	

	//Get when something was clicked and our tool was out to automagically switch to our tool
	//"Polish" - bletotum
	function coasterClick(  clicked, mousecode )
		if clicked && mousecode == MOUSE_LEFT && LocalPlayer():GetTool() && LocalPlayer():GetTool().Name == "Rollercoaster SuperTool" then
			if LocalPlayer():GetInfoNum("coaster_autoswitch") == 0 then return end
			RunConsoleCommand("use", "gmod_tool") //select the tool gun
		end

	end
	hook.Add( "VGUIMousePressed", "CoasterAutoswitchtool", coasterClick ) 

	language.Add( "tool.coaster_supertool.name", "" )
	language.Add( "tool.coaster_supertool.desc", "" )
	language.Add( "tool.coaster_supertool.0", "" )

end

