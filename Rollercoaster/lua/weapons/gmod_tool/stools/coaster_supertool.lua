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
		if self.CurrentClass && self.CurrentClass.Holster then
			self.CurrentClass:Holster( self )
		end

		if class && class.Equip then
			class:Equip( self )

			//Update the header HUD
			//if CLIENT then
				//print(class.Name)
				//language.remove("Tool_coaster_supertool_name")
				//language.Add( "Tool_coaster_supertool_name", class.Name )
				//language.Add( "Tool_coaster_supertool_desc", class.Description )
			//end
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
	if !class then return end

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
	if !class then return end

	local text = "None"
	if class.Name then text = class.Name end
	if class.Name == "" && class.Name2 then text = class.Name2 end //quickfix

	surface.SetFont("GModToolScreen")
	DrawScrollingText( text, 64, TEX_SIZE )
end

function toSortedTable( T, member )
	local max = Count( T )
	local num = 1
	local newTbl = {}

	for i=1, 6 do
		for k, v in pairs( T ) do
			if v.Position == i then
				newTbl[i] = T[k]
				break
			end
		end
	end

	return newTbl
end

//I dont know what garry's table.Count does, but it returns the wrong answer if all the indices are strings. So I made my own.
function Count( tbl )
	local count = 0
	for k, v in pairs( tbl ) do
		count = count + 1
	end
	
	return count
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

	//The little property sheet to hold all of the tracks to build
	local AllTracks = vgui.Create("DForm", panel )
	AllTracks:SetName("Specific Track Building")

	local trackList = vgui.Create("DListView", AllTracks )
	trackList:SetName("Track List")
	trackList:AddColumn("Owner")
	local id = trackList:AddColumn("ID")
	local build = trackList:AddColumn("Build Track")
	build:SetWidth(30)
	id:SetWidth( 5 )


	UpdateTrackPanel( trackList )

	trackList:SetSize( 360, 120 )
	panel.CoasterList = trackList 

	AllTracks:AddItem(trackList)

	AllTracks:SetExpanded( false )


	panel:AddItem(AllTracks)


	local btnBuildMine = vgui.Create("DButton", panel )
	btnBuildMine:SetText("Build Mine")
	btnBuildMine:SetTooltip("Build only the meshes of your own tracks")
	btnBuildMine.DoClick = function()
		for _, v in pairs( ents.FindByClass("coaster_node") ) do
			if IsValid( v ) && v:IsController() && v:GetOwner() == LocalPlayer() then 
				v:UpdateClientMesh()
			end
		end
	end

	local btnBuildAll = vgui.Create("DButton", panel )
	btnBuildAll:SetText("Build All")
	btnBuildAll:SetTooltip("Build the mesh for all existing tracks")
	btnBuildAll:SetConsoleCommand("coaster_update_mesh")

	panel:AddItem( btnBuildMine, btnBuildAll )

	btnBuildMine:Dock( RIGHT )
	btnBuildMine:SetWidth(140)

	btnBuildAll:Dock( LEFT )
	btnBuildAll:SetWidth(140)


	btnBuildAll:GetParent():SetHeight(30)


	//panel:Button( "Build All Meshes", "coaster_update_mesh")
	panel:ControlHelp( "Note: Building the mesh is not realtime. Your game WILL freeze when building mesh." )
	local version = panel:Help( "Rollercoaster version: " .. COASTER_VERSION )
end



if CLIENT then	

	language.Add( "tool.coaster_supertool.name", "" )
	language.Add( "tool.coaster_supertool.desc", "" )
	language.Add( "tool.coaster_supertool.0", "" )


	function UpdateTrackPanel( panel )
		if panel == nil then return end 
		panel:Clear()

		local found = {}
		local exists = false
		local coasterid = "dicks"

		for k, v in pairs( ents.FindByClass("coaster_node") ) do
			exists = false
			coasterid = v:GetCoasterID()

			for m, t in pairs( found ) do
				if coasterid == m then 
					exists = true
					continue
				end
			end

			if !exists then
				found[coasterid] = v
			end
		end

		for k, v in pairs( found ) do
			btn = vgui.Create("DButton", panel )
			btn:SetText( "Build" )
			btn:CenterHorizontal()
			btn:SetWidth( 30 )
			btn:SetHeight( 10 )
			btn.DoClick = function()
				if !IsValid( v ) || !IsValid( v:GetController() ) then return end
				
				v:GetController():UpdateClientMesh()
			end
			if IsValid( v ) && IsValid( v:GetController() ) then
				if v:HasInvalidNodes() then
					btn:SetColor( Color( 255, 0, 0 ))
				end
			end
			
			local expld = string.Explode("_", k )
			
			local name = "UNKNOWN"
			if IsValid( v:GetOwner() ) then name = v:GetOwner():Name() end
			
			local line = panel:AddLine( name, expld[#expld], btn )
		end
	end


	hook.Add("OnEntityCreated", "Coaster_UpdateList", function( ent )
		local panel = controlpanel.Get("coaster_supertool")

		if IsValid( ent ) && ent:GetClass() == "coaster_node" && panel && panel.CoasterList then
			timer.Simple(0, function() 
				UpdateTrackPanel(panel.CoasterList)
			end )
		end

	end )

	hook.Add("EntityRemoved", "Coaster_UpdateList", function( ent )
		local panel = controlpanel.Get("coaster_supertool")

		if IsValid( ent ) && ent:GetClass() == "coaster_node" && panel && panel.CoasterList then
			timer.Simple(0, function() 
				UpdateTrackPanel(panel.CoasterList)
			end )
		end

	end )

end

