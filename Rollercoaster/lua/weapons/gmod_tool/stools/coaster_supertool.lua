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

function TOOL:ShouldModifyNode( entity )
	local Node = self:GetActualNodeEntity( entity )
	local Controller = IsValid( Node ) and Node:GetController() or nil

	//They can modify it if they're the owner, admin, or a hook overrides access
	return IsValid(Controller) && ( Controller:GetOwner() == self:GetOwner() || self:GetOwner():IsAdmin() || hook.Call("Coaster_ShouldModifyNode", GAMEMODE, Node, self:GetOwner() ) || game.SinglePlayer() )
end

//A helper function to return the node whether we are that same node or a physics mesh
function TOOL:GetActualNodeEntity( entity )
	if !IsValid( entity ) then return nil end

	if entity:GetClass() == "coaster_node" then 
		return entity
	else 
		if entity.GetController && IsValid( entity:GetController() ) && entity:GetController().GetCoasterID then
			return entity:GetController().Nodes[ entity.Segment ]
		end
	end

	return nil
end


//I dont know what garry's table.Count does, but it returns the wrong answer if all the indices are strings. So I made my own.
local function Count( tbl )
	local count = 0
	for k, v in pairs( tbl ) do
		count = count + 1
	end
	
	return count
end

local function toSortedTable( T, member )
	local max = Count( T )
	local num = 1
	local newTbl = {}

	for i=1, 6 do
		for k, v in pairs( T ) do
			if v[member] == i then
				newTbl[i] = T[k]
				break
			end
		end
	end

	return newTbl
end

function TOOL.BuildCPanel(panel)	
	panel.Header:SetSize( 0, 0 )
	panel.Header:SetAlpha( 0 )
	panel:SetPadding( 0 )
	panel.Paint = function() return true end

	local PropertySheet = vgui.Create( "DPropertySheet", panel )
	PropertySheet:SetPos( 0, 0 )
	PropertySheet:SetSize( 360, 560 ) //340, 600

	local FixedTable = toSortedTable( coastertabmanager.List, "Position")

	for k, v in pairs(FixedTable) do
		local panel = v:BuildPanel()
		panel:SetPadding( 0, 0, 0, 0)
		RegisterTabPanel( panel, v.UniqueName )
		
		local sheet = PropertySheet:AddSheet( v.Name, panel, v.Icon, false, false, v.Description )	
		sheet.Tab.Class = v
	end

	panel:AddItem( PropertySheet )
	PropertySheet:DockPadding(0, 0, 0, 0)
	PropertySheet:DockMargin(0, 0, 0, 0)
	PropertySheet:SetPadding( 10, 0 )

	panel.Tabs = PropertySheet

	//The little property sheet to hold all of the tracks to build
	local AllTracks = vgui.Create("DForm", panel )
	AllTracks:SetName("Specific Track Building")
	AllTracks.AnimateManual = function(self) 
		self.animSlide:Start( self:GetAnimTime(), { From = self:GetTall() } )
		
		self:InvalidateLayout( true )
		self:GetParent():InvalidateLayout()
		self:GetParent():GetParent():InvalidateLayout()
		
		local cookie = '1'
		if ( !self:GetExpanded() ) then cookie = '0' end
		self:SetCookie( "Open", cookie )
	end

	local trackList = vgui.Create("DListView", AllTracks )
	trackList:SetName("Track List")
	trackList:AddColumn("Owner")
	local id = trackList:AddColumn("ID")
	local build = trackList:AddColumn("Build Track")
	build:SetWidth(30)
	id:SetWidth( 5 )

	trackList:SetSize( 360, 120 )
	trackList.OwnerForm = AllTracks
	panel.CoasterList = trackList 

	-- Update the list now
	UpdateTrackPanel( trackList )

	AllTracks:AddItem(trackList)
	AllTracks:SetExpanded( false )


	panel:AddItem(AllTracks)


	local btnBuildMine = vgui.Create("DButton", panel )
	btnBuildMine:SetText("Build Mine")
	btnBuildMine:SetTooltip("Build only the meshes of your own tracks")
	btnBuildMine.DoClick = function()
		for _, v in pairs( ents.FindByClass("coaster_node") ) do
			if IsValid( v ) && v:GetIsController() && v:GetOwner() == LocalPlayer() then 
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
	btnBuildMine:SetWidth(100)

	btnBuildAll:Dock( LEFT )
	btnBuildAll:SetWidth(100)


	btnBuildAll:GetParent():SetHeight(30)


	//panel:Button( "Build All Meshes", "coaster_update_mesh")
	panel:ControlHelp( "Note: Building the mesh is an intensive process. Performance will be affected." )
	local version = panel:Help( "Rollercoaster version: " .. COASTER_VERSION )
end



if CLIENT then	

	language.Add( "tool.coaster_supertool.name", "" )
	language.Add( "tool.coaster_supertool.desc", "" )
	language.Add( "tool.coaster_supertool.0", "" )

	hook.Add("CoasterBuildProgress", "UpdateTrackPanelProgress", function( coasterID, stage, percent )
		local panel = controlpanel.Get("coaster_supertool").CoasterList
		if !panel then return end 

		local lines = panel:GetLines()

		for k, v in pairs( lines ) do
			if v.CoasterID == coasterID && v.Button then
				v.Button:SetFraction( percent )
				return
			end
		end
	end )

	function UpdateTrackPanel( panel )
		if panel == nil then return end 
		panel:Clear()

		local found = {}

		for k, v in pairs( ents.FindByClass("coaster_node") ) do
			if IsValid( v ) && v.GetCoasterID && v.GetIsController && v:GetIsController() then
				found[v:GetCoasterID()] = v
			end
		end

		local HasUnbuiltCoasters = false
		for k, v in pairs( found ) do
			if !IsValid( v ) || !v.GetController || !v:GetController() then continue end

			btn = vgui.Create("DProgressButton", panel )
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
					HasUnbuiltCoasters = true
				end

				if v.BuildingMesh then
					btn:SetText("Building...")
					btn:SetShowProgress( true )

					HasUnbuiltCoasters = true
				else
					btn:SetShowProgress( false )
					btn:SetFraction( 0 )
				end
			end
			
			local expld = string.Explode("_", k )
			
			local name = "UNKNOWN"
			if IsValid( v:GetOwner() ) then name = v:GetOwner():Name() end
			
			local line = panel:AddLine( name, expld[#expld], btn )
			line.CoasterID = v:GetCoasterID()
			line.Button = btn
		end

		//Change the expansion state if there's a coaster building
		if HasUnbuiltCoasters then
			if !panel.OwnerForm:GetExpanded() then
				panel.OwnerForm:SetExpanded( true )
				panel.OwnerForm:AnimateManual()
			end
		else
			panel.OwnerForm:SetExpanded( false )
			panel.OwnerForm:AnimateManual()
		end
	end


	hook.Add("OnEntityCreated", "Coaster_UpdateList", function( ent )
		local panel = controlpanel.Get("coaster_supertool")

		if isentity(ent) && IsValid( ent ) && ent:GetClass() == "coaster_node" && panel && panel.CoasterList then
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

