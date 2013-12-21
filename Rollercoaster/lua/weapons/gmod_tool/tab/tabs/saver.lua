include("weapons/gmod_tool/tab/tab_utils.lua")
include("autorun/mesh_beams.lua")

local TAB = {}
TAB.ClientConVar = {}
local UNIQUENAME = "saver"

TAB.Name = "Save/Load"
TAB.UniqueName = UNIQUENAME
TAB.Description = "Save, load, and upload tracks"
TAB.Instructions = "Right click on a coaster to select it to save. Left click to spawn a loaded coaster."
TAB.Icon = "coaster/save"
TAB.Position = 4 //The position in the series of tabs

TAB.ClientConVar["id"] = "1"
TAB.ClientConVar["orig_spawn"] = "1"

TAB.GhostModel = Model("models/Combine_Helicopter/helicopter_bomb01.mdl")
TAB.WaitTime	= 0 //Time to wait to make sure the dtvars are updated
TAB.CoolDown 	= 0 //For some reason, LeftClick is called four times when pressed once. :/
TAB.CoolDownR	= 0

//Some uniquely named global variables
TAB.SelectedController = nil
coaster_saver_ClipboardTrack = {} //The coaster track loaded into the 'clipboard', to be saved or loaded
coaster_saver_selectedfilename = ""
coaster_saver_preview_trackmesh = nil
coaster_saver_preview_trackcenter = Vector( 0, 0, 0 )
coaster_saver_preview_shoulddraw = false

//Generation constants
coaster_save_preview_material = Material("Models/effects/comball_tape")

//Useful enums
TRANSFER_TRACKLIST 	= 1
TRANSFER_PREVIEW	= 2
TRANSFER_TRACK  	= 3
TRANSFER_SAVE		= 4
TRANSFER_UPLOAD 	= 5

if SERVER then
	util.AddNetworkString("Coaster_transferInfo")
end

function TAB:LeftClick( trace, tool )
	if CurTime() < self.CoolDown then return end

	if game.SinglePlayer() then 
		if tool:GetOwner().SpawningCoaster then return false end
	end

	if CLIENT || game.SinglePlayer() then
		if !coaster_saver_selectedfilename or coaster_saver_selectedfilename == "" && !game.SinglePlayer() then return false end

		self:SpawnTrack( tool )
		self.CoolDown = CurTime() + .25

		coaster_saver_preview_shoulddraw = false

		return true
	end
end

function TAB:RightClick( trace, tool )
	if CurTime() < self.CoolDownR then return end //Prevent from being called many times per click
	self.CoolDownR = CurTime() + 0.10

	local ply   = tool:GetOwner()
	
	if IsValid( trace.Entity ) && ( trace.Entity:GetClass() == "coaster_node" || trace.Entity:GetClass() == "coaster_physmesh" ) then
		if IsValid( trace.Entity:GetController() ) then
			self.SelectedController = trace.Entity:GetController()

			if CLIENT then
				GAMEMODE:AddNotify( "Selected " .. tostring( self.SelectedController:GetCoasterID() ), NOTIFY_GENERIC, 3 )
			end

			if game.SinglePlayer() then
				umsg.Start( "coaster_rightclick_sp", ply )
				umsg.End()
			end
		end

		/*
		if IsValid( trace.Entity:GetController() ) && CLIENT then
			self.SelectedController = trace.Entity:GetController()
			CreateTrackTable( trace.Entity:GetController() )
			GAMEMODE:AddNotify( "Track copied into clipboard", NOTIFY_GENERIC, 3 )

		elseif game.SinglePlayer() then
			//Tell the client to do something. I have to do this because this isn't called clientside in game.SinglePlayer
			//This is due to no prediction in game.SinglePlayer, but it'd be nice if garry had this called clientside anyway
			umsg.Start("coaster_rightclick_sp")
				umsg.Entity( tool:GetOwner() )
			umsg.End()
		end
		*/
		return true
	end
end

usermessage.Hook("coaster_rightclick_sp", function( um ) 
	local ply = LocalPlayer()

	if !IsValid( ply ) then return end
	local tool = LocalPlayer():GetTool()
	local tab = nil
	if tool.Name != "Rollercoaster SuperTool" || tool:GetCurrentTab().UniqueName != "saver" then return end
	tab = tool:GetCurrentTab()

	local trace = {}
	trace.start  = ply:GetShootPos()
	trace.endpos = trace.start + (ply:GetAimVector() * 99999999)
	trace.filter = ply
	trace = util.TraceLine(trace)

	if IsValid( trace.Entity ) && ( trace.Entity:GetClass() == "coaster_node" || trace.Entity:GetClass() == "coaster_physmesh" ) then
		if IsValid( trace.Entity:GetController() ) then
			tab.SelectedController = trace.Entity:GetController()
			GAMEMODE:AddNotify( "Selected " .. tostring( tab.SelectedController:GetCoasterID() ), NOTIFY_GENERIC, 3 )
		end

	end

end )

function CreateTrackTable( controller )
	coaster_saver_ClipboardTrack = {} //This will be the table holding all of the information we'll need to later create the coaster

	for k, v in pairs( controller.Nodes ) do
		coaster_saver_ClipboardTrack[k] = {}
		coaster_saver_ClipboardTrack[k].Pos = tostring(v:GetPos())
		coaster_saver_ClipboardTrack[k].Ang = tostring(v:GetAngles())
		coaster_saver_ClipboardTrack[k].Type = v:GetNodeType()
		coaster_saver_ClipboardTrack[k].Roll = v:GetRoll()
		coaster_saver_ClipboardTrack[k].Color = v:GetColor()
		coaster_saver_ClipboardTrack[k].TrackColor = v:GetActualTrackColor()
		if v:GetNodeType()==COASTER_NODE_LAUNCH then
			coaster_saver_ClipboardTrack[k].LaunchSpeed=v:GetLaunchSpeed()
			coaster_saver_ClipboardTrack[k].LaunchKeyString=v:GetLaunchKeyString()
			coaster_saver_ClipboardTrack[k].LaunchKey=v:GetLaunchKey()
		end
	end

	coaster_saver_ClipboardTrack.numnodes = #controller.Nodes
	coaster_saver_ClipboardTrack.looped = tostring(controller:GetLooped())
end

function TAB:Reload( trace )

end

//Called when our tab is closing or the tool was holstered
function TAB:Holster()
	if CLIENT then
		coaster_saver_preview_shoulddraw = false
	end
end

//Called when our tab being selected
function TAB:Equip( tool )
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
				SelectAllNodes( controller, Color( 180 - math.random( 0, 80 ), 220 - math.random( 0, 50 ), 255, 255 ) )
			end
		end

		UpdateTrackList()

		coaster_saver_preview_shoulddraw = true
	end
end

function TAB:Think( tool )

end

function TAB:BuildPanel( )
	local panel = vgui.Create("DForm")
	panel:SetName("Save/Load/Upload Completed Tracks")

	local tracklist = vgui.Create("DListView")
	tracklist:SetParent( panel )
	tracklist:SetMultiSelect( false )
	tracklist:AddColumn("Track Name")
	tracklist:AddColumn("Author")
	//tracklist:AddColumn("Filepath")
	tracklist:SetTall( 200 )

	panel:AddItem( tracklist )
	panel.tracklist = tracklist

	local btnRefresh = panel:Button("Refresh")
	btnRefresh.DoClick = function() UpdateTrackList() end

	local btnLoad = panel:Button("Load Selected")
	btnLoad.DoClick = function() LoadSelectedTrack() end

	if !game.SinglePlayer() then
		local upload = panel:Button("Upload...")
		upload.DoClick = function() OpenCoasterUploadMenu() end
	end
	panel:NumSlider( "Rollercoaster ID: ", "coaster_supertool_tab_saver_id", 1, 8, 0 )

	panel:CheckBox("Spawn at original position and angles", "coaster_supertool_tab_saver_orig_spawn")

	local Seperator = vgui.Create("DLabel", panel)
	Seperator:SetText("______________________________________________")
	panel:AddItem( Seperator )

	local btnSave = panel:Button("Save Rollercoaster")
	btnSave.DoClick = function() OpenCoasterSaveMenu() end

	//panel:AddControl("Button",	 {Label = "Save Rollercoaster", Description = "Save the currently copied track", DoClick = function() OpenCoasterSaveMenu() end }) 

	//panel:AddControl( "Header", { Text = "#Tool_coaster_track_saver_name", Description = "#Tool_track_saver_desc" }  )

	return panel
end

function TAB:SpawnTrack( tool )
	if game.SinglePlayer() then //I'm seriously sending a usermessage to the client, who is the host. WHY IS LEFTCLICK NOT CALLED ON THE CLIENT IN game.SinglePlayer
		umsg.Start("Coaster_spawntrack_sp")
			umsg.String( tool:GetOwner():SteamID() .. "_" .. tostring( GetClientNumber( self, "id", tool ) ) )
			umsg.Short( GetClientNumber( self, "orig_spawn", tool ) )
			umsg.Vector( coaster_saver_preview_trackcenter )
		umsg.End()
	else
		RunConsoleCommand( "coaster_supertool_tab_saver_spawntrack", coaster_saver_selectedfilename, LocalPlayer():SteamID() .. "_" .. tostring( GetClientNumber( self, "id", tool ) ),  GetClientNumber( self, "orig_spawn", tool ), coaster_saver_preview_trackcenter )
		print("Building \"" .. coaster_saver_selectedfilename .. "\"")
	end
end


function OpenCoasterSaveMenu()
	//Move this to before we open the save menu
	local controller = nil
	local tool = LocalPlayer():GetTool()

	if tool.Name == "Rollercoaster SuperTool" && tool:GetCurrentTab().UniqueName == "saver" then
		controller = tool:GetCurrentTab().SelectedController
	end


	local form = vgui.Create( "DFrame" )
	form:SetSize( 250, 300 ) //289
	form:SetTitle("Save Rollercoaster")
	form:Center()
	form:SetVisible( true )
	form:SetDraggable( true )
	form:ShowCloseButton( false )
	form:MakePopup()
	form.Paint = function() draw.RoundedBox( 8, 0, 0, form:GetWide(), form:GetTall(), Color( 0,0,0,150)) end //Make it invisible
	
	local panel = vgui.Create("DForm", form)

	panel:SetSize(form:GetSize())

	panel:SetPos( 0, 25)

	panel:SetName("")


	local LabelName = vgui.Create("DLabel", panel)
	LabelName:SetText("Name:")
	panel:AddItem( LabelName )


	local DName = vgui.Create("DTextEntry")
	DName.Label = "#Name"
	DName:SetParent( panel )
	panel:AddItem( DName )
	panel.DName = DName

	local LabelDesc = vgui.Create("DLabel", panel)
	LabelDesc:SetText("Description:")
	panel:AddItem( LabelDesc )

	local DDesc = vgui.Create("DTextEntry")
	DDesc.Label = "#Description"
	DDesc:SetMultiline( true )
	DDesc:SetTall(84)
	DDesc:SetParent( panel )
	panel:AddItem( DDesc )
	panel.DDesc = DDesc

	local btnSave = vgui.Create("Button")
	btnSave:SetText("Save")
	btnSave:SetToolTip( "Save the file on your local computer.")
	btnSave.DoClick = function() 
		if IsValid( controller ) then
			SaveTrack(DName:GetValue(), DDesc:GetValue(), controller, false ); form:Close(); 
			surface.PlaySound("garrysmod/content_downloaded.wav") 
		else
			GAMEMODE:AddNotify( "No track selected!", NOTIFY_ERROR, 6 )
	       	surface.PlaySound( "buttons/button10.wav" )
		end
	end
	panel:AddItem( btnSave )

	if !game.SinglePlayer() then
		form:SetSize( 250, 332 ) //289

		local btnSaveUp = vgui.Create("Button")
		btnSaveUp:SetText("Save and Upload")
		btnSaveUp:SetToolTip( "Save the file on both your local computer and the server.\nIt will be available in the server track list.")
		btnSaveUp.DoClick = function() 
			if IsValid( controller ) then
				SaveTrack(DName:GetValue(), DDesc:GetValue(), controller, true ); form:Close(); 
				surface.PlaySound("garrysmod/content_downloaded.wav") 
			else
				GAMEMODE:AddNotify( "No track selected!", NOTIFY_ERROR, 6 )
		       	surface.PlaySound( "buttons/button10.wav" )
			end
		end
		panel:AddItem( btnSaveUp )
	end

	local btnCancel = vgui.Create("Button")
	btnCancel:SetText("Cancel")

	btnCancel.DoClick = function() form:Close() end
	panel:AddItem( btnCancel )
end


function OpenCoasterUploadMenu()
	//Set up our form
	local panel = GetTabPanel( "saver" )

	local form = vgui.Create( "DFrame" )
	form:SetSize( 250, 325 )
	form:SetTitle("Upload Track to Server")
	form:Center()
	form:SetVisible( true )
	form:SetDraggable( true )
	form:ShowCloseButton( false )
	form:MakePopup()
	form.Paint = function() draw.RoundedBox( 8, 0, 0, form:GetWide(), form:GetTall(), Color( 0,0,0,150)) end //Make it invisible

	local panel = vgui.Create("DForm", form, "coaster_track_saver_uploadpanel")
	panel:SetSize( form:GetSize())
	//panel:Center()
	panel:SetPos( 0, 25)
	//local px, py = panel:GetPos()
	//panel:SetPos( px - (x / 2), py - (y / 2) )
	panel:SetName(" ")

	//Create the list view listing clientside files
	local tracklist = vgui.Create("DListView", panel)
	tracklist:SetParent( panel )
	tracklist:SetMultiSelect( false )
	tracklist:AddColumn("Track Name")
	tracklist:AddColumn("Author")
	//tracklist:AddColumn("Filepath")
	tracklist:SetTall( 200 )
	panel:AddItem( tracklist )
	panel.tracklist = tracklist

	//Create our buttons
	local btnUpload = vgui.Create("Button")
	btnUpload:SetText("Upload")
	btnUpload.DoClick = function() 
		local line = tracklist:GetLine( tracklist:GetSelectedLine() )
		if line then 
			UploadFile( line:GetValue(3) ); 
			GAMEMODE:AddNotify( "Uploading " .. line:GetValue(1) .. " to the server!", NOTIFY_GENERIC, 4 )
		end
		form:Close(); 
		surface.PlaySound("garrysmod/content_downloaded.wav")
	end
	panel:AddItem( btnUpload )

	local btnCancel = vgui.Create("Button")
	btnCancel:SetText("Cancel")
	btnCancel.DoClick = function() form:Close() end
	panel:AddItem( btnCancel )


	//Get a list of local files
	local list, folders = file.Find("Rollercoasters/*.txt", "DATA")
	for _, f in pairs( list ) do
		local contents = file.Read( "Rollercoasters/" .. f ) //Is there a way to get the full file path of the file?
		local tbl = util.KeyValuesToTable( contents )
		local name = tbl.name or f
		local author = tbl.author or "unknown"

		local line = panel.tracklist:AddLine( name, author )
		line:SetValue(3, "Rollercoasters/" .. f)
		//line.PaintOver = function() draw.SimpleText(name, "DefaultSmall", 3, 2, Color( 0, 255, 0, 255)) end //Default to green text

		toolpanel = GetTabPanel( "saver" )
		if toolpanel && toolpanel.tracklist != nil then
			for k, v in pairs( toolpanel.tracklist:GetLines() ) do
				if v:GetValue(1) == name then
					//line.PaintOver = function() draw.SimpleText(name, "DefaultSmall", 3, 2, Color( 255, 0, 0, 255)) end //File exists
				end
			end
		end
	end
end


//Upload a specific file to the server
function UploadFile( filepath )
	if file.Exists( filepath, "DATA" ) then
		local contents = file.Read( filepath ) //Is there a way to get the full file path of the file?
		print("Uploading file: " .. filepath )
		local tbl = util.KeyValuesToTable( contents )

		net.Start("Coaster_transferInfo")
			net.WriteInt( TRANSFER_UPLOAD, 4 )
			net.WriteTable( tbl )
		net.SendToServer(LocalPlayer())
	end

end

function RemoveInvalidChars(str)
	local BadChars = {"\\", "/", ":", "*", "?", "\"", "<", ">", "¦", "|", "'"}
	for _,char in pairs(BadChars) do
		str = string.gsub(str, char, "_")
	end

	return str
end

function SaveTrack(name, desc, controller, saveOnServer )
	net.Start("Coaster_transferInfo")
		net.WriteInt( TRANSFER_SAVE, 4 )
		net.WriteInt( saveOnServer and 1 or 0, 2)
		net.WriteEntity( controller )
		net.WriteString( name )
		net.WriteString( desc )
	net.SendToServer( LocalPlayer() )
	/*
	if coaster_saver_ClipboardTrack != nil && #coaster_saver_ClipboardTrack > 0 then
		name = RemoveInvalidChars( name )
		name = string.Replace(name, ".", "_")

		print(name)
		coaster_saver_ClipboardTrack["name"] = name
		coaster_saver_ClipboardTrack["author"] = LocalPlayer():GetName()// self:GetOwner():Name()
		coaster_saver_ClipboardTrack["description"] = desc

		local towrite = util.TableToKeyValues(coaster_saver_ClipboardTrack) 

		local dirlist = file.FindDir("Rollercoasters", "DATA" )
		if #dirlist < 1 then
			file.CreateDir("Rollercoasters")
			print("Creating new directory..")
		end

		file.Write("Rollercoasters/" .. name .. ".txt", towrite)

		//Update with the newly saved track
		UpdateTrackList()

		//The user wanted to save and upload
		if upload then
			UploadFile( "Rollercoasters/" .. name .. ".txt" ); 
			GAMEMODE:AddNotify( "Uploading " .. name .. " to the server!", NOTIFY_GENERIC, 4 )
		end
	else
		print("Failed to save rollercoaster: " .. coaster_saver_ClipboardTrack )
	end
	*/
end


function UpdateTrackList()
	local panel = GetTabPanel( "saver" )

	if panel && panel.tracklist != nil then
		print("Updating local track list...")
		panel.tracklist:Clear()

		if game.SinglePlayer() then //update from locally saved files
			local list, folders = file.Find("Rollercoasters/*.txt", "DATA")
			for _, f in pairs( list ) do
				local contents = file.Read( "Rollercoasters/" .. f ) //Is there a way to get the full file path of the file?
				local tbl = util.KeyValuesToTable( contents )
				local name = tbl.name or f
				local author = tbl.author or "unknown"

				local line = panel.tracklist:AddLine( name, author )
				line:SetValue(3, "Rollercoasters/" .. f)
			end
		else //Multiplayer game
			//Request a list of files from the server
			RunConsoleCommand("coaster_supertool_tab_saver_requesttracklist")
		end
		panel:InvalidateLayout()
	end
end

//Send the file list back to the player
function RequestTrackList(ply)
	if CLIENT then return end //serverside only

	local files, folders = file.Find("Rollercoasters/Server/*.txt", "DATA")

	if !files then return end
	//Build a list of tracks into a table
	local tracklist = {}

	for _, f in pairs( files ) do
		local contents = file.Read( "Rollercoasters/Server/" .. f ) //Is there a way to get the full file path of the file?
		local tbl = util.KeyValuesToTable( contents )
		local name = tbl.name or f
		local author = tbl.author or "unknown"

		tracklist[f] = {}
		tracklist[f].name = name
		tracklist[f].author = author
	end	

	//Send it to the client
	net.Start("Coaster_transferInfo")
		net.WriteInt( TRANSFER_TRACKLIST, 4 )
		net.WriteTable( tracklist )
	net.Send( ply )

end


function LoadSelectedTrack()
	local panel = GetTabPanel( "saver" )
	if panel && panel.tracklist != nil then
		print("Loading track...")
		local line = nil
		local num = panel.tracklist:GetSelectedLine()
		if num then
			line = panel.tracklist:GetLine( num )
		else
			print("Failed to load track - No selected track. (" .. tostring( num ) .. ")")
			GAMEMODE:AddNotify( "No selected track", NOTIFY_ERROR, 5 )
			return 
		end

		if line then
			coaster_saver_selectedfilename = line:GetValue( 1 ) .. ".txt"

			GAMEMODE:AddNotify( "Loaded " .. coaster_saver_selectedfilename, NOTIFY_GENERIC, 5 )

			if !line.PreviewTable then
				RunConsoleCommand("coaster_supertool_tab_saver_requestpreview", coaster_saver_selectedfilename )
			else
				print("Preview already downloaded! Using that.")
				GeneratePreview( line.PreviewTable )
			end

			coaster_saver_preview_shoulddraw = true

		else
			print("Failed to load track - Line was nil")
			GAMEMODE:AddNotify( "No selected track", NOTIFY_ERROR, 5 )
			return
		end
	end
end

function GeneratePreview( positions_tbl )
	if !positions_tbl || #positions_tbl < 4 then return end

	if coaster_saver_preview_trackmesh then 
		coaster_saver_preview_trackmesh:Destroy()
		coaster_saver_preview_trackmesh = nil
	end

	//Create a catmull object to calculate our curve stuff
	local CatmullRom = CoasterManager.Controller:New( self )
	CatmullRom:Reset()
	CatmullRom.DisableDynamicStep = true //Don't let it generate from the chosen slider amount
	CatmullRom.STEPS = 5

	local AvgVector = Vector( 0, 0, 0 )
	local highestX = math.huge
	local highestY = math.huge
	local lowestX = -math.huge
	local lowestY = -math.huge

	local lowestZ = math.huge

	//Add all the points to the catmull controller
	for i=1, #positions_tbl do 
		CatmullRom:AddPoint( i, Vector( positions_tbl[i] ) )

		//While we're here, average out the center of the coaster
		if Vector( positions_tbl[i] ).x > lowestX then lowestX = Vector( positions_tbl[i] ).x end
		if Vector( positions_tbl[i] ).x < highestX then highestX = Vector( positions_tbl[i] ).x end 

		if Vector( positions_tbl[i] ).y > lowestY then lowestY = Vector( positions_tbl[i] ).y end 
		if Vector( positions_tbl[i] ).y < highestY then highestY = Vector( positions_tbl[i] ).y end

		//Make it so the average isnt in some strange place in the ground
		if Vector( positions_tbl[i] ).z < lowestZ then 
			lowestZ = Vector( positions_tbl[i] ).z
		end
	end
	AvgVector.x = ( highestX + lowestX ) / 2
	AvgVector.y = ( highestY + lowestY ) / 2

	AvgVector.z = lowestZ
	coaster_saver_preview_trackcenter = AvgVector

	//Calc the entire spline
	CatmullRom:CalcEntireSpline()

	//Now, build the mesh
	local Vertices = {} //Create an array that will hold an array of vertices (This is to split up the model)
	local Meshes = {} 
	local Radius = 18
	local modelCount = 1 

	local Cylinder = Cylinder:Create()
	Cylinder.Count = 6

	local LastAngle = Angle( 0, 0, 0 )
	local ThisAngle = Angle( 0, 0, 0 )

	local ThisPos = Vector( 0, 0, 0 )
	local NextPos = Vector( 0, 0, 0 )
	for i = 1, #CatmullRom.Spline do
		ThisPos = CatmullRom.Spline[i]
		NextPos = CatmullRom.Spline[i+1]

		if i==#CatmullRom.Spline then
			NextPos = CatmullRom.PointsList[#CatmullRom.PointsList-1]
		end
		local ThisAngleVector = ThisPos - NextPos
		ThisAngle = ThisAngleVector:Angle()

		ThisAngle:RotateAroundAxis( ThisAngleVector:Angle():Right(), 90 )
		ThisAngle:RotateAroundAxis( ThisAngleVector:Angle():Up(), 270 )

		if i==1 then LastAngle = ThisAngle end

		Cylinder:AddBeam(ThisPos, LastAngle, NextPos, ThisAngle, Radius )

		LastAngle = ThisAngle
	end

	local Verts = Cylinder:EndBeam()

	coaster_saver_preview_trackmesh = Mesh()
	coaster_saver_preview_trackmesh:BuildFromTriangles( Verts )
end


usermessage.Hook("Coaster_spawntrack_sp", function(um) 
	RunConsoleCommand( "coaster_supertool_tab_saver_spawntrack", coaster_saver_selectedfilename, um:ReadString() or 1, um:ReadShort(), um:ReadVector() )
	print("Building \"" .. coaster_saver_selectedfilename .. "\"")
end )

//Activate things on the server (not really enough to govern a net function)
if SERVER then
	local controllernode = nil
	function SpawnNode( ply, nodeinfo, i, num, filename, id, looped, orig_spawn, TranslateTo, AngleTo, AveragePos)

		local pos = Vector( nodeinfo.pos )
		local ang = Angle( nodeinfo.ang )
		local color = Color( nodeinfo.color.r, nodeinfo.color.g, nodeinfo.color.b )

		if !orig_spawn then
			pos = pos - AveragePos
			local newPos, newAng = LocalToWorld( pos, ang, TranslateTo, AngleTo )

			pos = newPos
		end


		local node = CoasterManager.CreateNodeSimple(id, pos, ang, ply )

		if !IsValid( node ) then return end

		node:SetRoll( nodeinfo.roll )
		node:SetNodeType( nodeinfo.type )
		node:SetColor( color  )
		if nodeinfo.trackcolor then //backwards compatibility 
			node:SetTrackColor( Vector(nodeinfo.trackcolor.r/255, nodeinfo.trackcolor.g/255, nodeinfo.trackcolor.b/255)  )
		end
		if nodeinfo.type==COASTER_NODE_LAUNCH then
			local key=nodeinfo.launchkey
			node:SetLaunchKey(key)
			node:SetLaunchKeyString(nodeinfo.launchkeystring)
			node:SetLaunchSpeed(nodeinfo.launchspeed)
			numpad.OnDown(ply,key,"CoasterLaunch",node,true)
			numpad.OnUp(ply,key,"CoasterLaunch",node,false)
			numpad.Register("CoasterLaunch",function(pl,nd,toggle)
				if !IsValid( nd ) then return end

				nd.Launching = toggle and #nd.CartsOnMe > 0
			end)
		end

		node.Filename = filename //Prevent duplicates of the coaster to be spawned

		if i==1 then //Controller node is _always_ the first node
			controllernode = node 
			controllernode:SetLooped( looped )
			controllernode:SetOwner( ply )
			controllernode.IsSpawning = true
		end

		if i==num && IsValid( controllernode ) then
			node:SetModel( "models/props_junk/PopCan01a.mdl" ) //Hide very last node

			controllernode:UpdateServerSpline()
			controllernode.IsSpawning = false

			timer.Simple( 0.2 , function() //Final delay in case any nodes were missed
				umsg.Start("Coaster_invalidateall")
					umsg.Entity( controllernode )
				umsg.End()
				ply.SpawningCoaster = false

				//Create a constraint with all the nodes so the duplicator picks them all up
				for k, v in pairs( controllernode.Nodes ) do
					constraint.NoCollide( v, controllernode, 0, 0 )
				end

			end )

			undo.Create("Saved Rollercoaster")
				undo.AddEntity( controllernode )
				undo.SetPlayer( ply )
				undo.SetCustomUndoText("Undone \"" .. filename .. "\"")
			undo.Finish()
		end

		//Force the client to update the spline
		if IsValid( controllernode ) then

			umsg.Start("Coaster_AddNode")
				umsg.Short( controllernode:EntIndex() )
			umsg.End()
		end
	end

	concommand.Add("coaster_supertool_tab_saver_requesttracklist", function(ply, cmd, args)
		RequestTrackList(ply)
	end)

	concommand.Add("coaster_supertool_tab_saver_requestpreview", function(ply, cmd, args)
		local filename = args[1]

		local directory ="Rollercoasters/Server/"
		if game.SinglePlayer() then directory = "Rollercoasters/" end

		if !file.Exists(directory .. filename, "DATA") then print("\"" .. filename .. "\" does not exist!" )  return end

		//Load the file
		local contents = file.Read( directory .. filename )
		local tbl = util.KeyValuesToTable( contents )


		if tbl then
			//Create the table holding the positions of all the nodes
			local PreviewTable = {}

			//Loop through all the keys in the table, only extracting the information we need
			for i=1, tbl.numnodes do
				local nodeinfo = tbl[i]

				//We ONLY want to send position. this is to cut down on generation time and network latency
				PreviewTable[i] = nodeinfo.pos
			end

			//If we have something to actually send, send it
			if #PreviewTable > 0 then

				//Send it to the client
				net.Start("Coaster_transferInfo")
					net.WriteInt( TRANSFER_PREVIEW, 4 )
					net.WriteString( filename )
					net.WriteTable( PreviewTable )
				net.Send( ply )
			end
		end
	end )

	concommand.Add("coaster_supertool_tab_saver_spawntrack", function(ply, cmd, args)
		if !IsValid( ply ) || ply.SpawningCoaster then 
			if IsValid( ply ) then ply:SendLua("GAMEMODE:AddNotify( " .. "\"You cannot spawn a coaster while another is still spawning!\"" .. ", NOTIFY_ERROR, 3 )") end  //I know I'm going to regret this, but I don't want to do it 'right'
			return 
		end //Don't do anything until they've stopped spawning a coaster

		local filename = args[1]
		local id = args[2] or ""
		local orig_spawn = math.Round(tonumber(args[3] ) ) == 1
		local TranslateTo = ply:GetEyeTrace().HitPos
		local AngleTo = ply:GetAngles()
		local AveragePos = args[4] or Vector( 0, 0, 0 )


		local directory ="Rollercoasters/Server/"
		if game.SinglePlayer() then directory = "Rollercoasters/" end

		if file.Exists(directory .. filename, "DATA") then

			//Load the file
			local contents = file.Read( directory .. filename )
			if !isstring( contents ) || #contents <= 0 then return end //GIT OUTTA HERE

			local tbl = util.KeyValuesToTable( contents )

			-- Check if anyone has any objections
			local res = hook.Run("Coaster_ShouldCreateNode", id, ply )
			if res != nil && res==false then 
				return
			end

			if tbl then
				print("Spawning coaster " .. filename )
				//print(tbl.numnodes)
				//local controllernode = nil

				if IsValid( Rollercoasters[id] ) then Rollercoasters[id]:Remove() end
				ply.SpawningCoaster = true
				for i=1, tbl.numnodes do
					local nodeinfo = tbl[i]
					local looped = tbl.looped == "true"

					//Please forgive me.
					//Spawning multiple entities in the same frame really fucked something on the client
					//The node was unable to be grabbed by the physgun, despite any settings applied to it
					//On the bright side, it makes a neat spawn effect
					timer.Simple( i / 10, function()
						SpawnNode( ply, nodeinfo, i, tbl.numnodes, filename, id, looped, orig_spawn, TranslateTo, AngleTo, AveragePos )
					end )
				end

			end
		end
	end )
end


//Use net library to send local file to server (If I may add, holy shit I love the net library)
if SERVER then

	net.Receive("Coaster_transferInfo", function( length, client )
		local transferType = net.ReadInt( 4 )

		if transferType == TRANSFER_UPLOAD then
			local Track = net.ReadTable()
			print("Received track " .. Track["name"] .. " from " .. client:GetName())

			local towrite = util.TableToKeyValues(Track) 

			file.CreateDir("Rollercoasters/Server")
			file.Write("Rollercoasters/Server/" .. Track["name"] .. ".txt", towrite)

			//Update them with the newest files
			RequestTrackList(client)
		elseif transferType == TRANSFER_SAVE then
			local save 			= net.ReadInt(2)
			local controller 	= net.ReadEntity()
			local name 			= net.ReadString()
			local desc 			= net.ReadString()

			name = RemoveInvalidChars( name )
			name = string.Replace(name, ".", "_")

			if !IsValid( controller ) then return end
			local trackTable = {}

			print("Generating track table \"" .. name .. "\" for " .. client:GetName() )

			for k, v in pairs( controller.Nodes ) do
				trackTable[k] = {}
				trackTable[k].Pos = tostring(v:GetPos())
				trackTable[k].Ang = tostring(v:GetAngles())
				trackTable[k].Type = v:GetNodeType()
				trackTable[k].Roll = v:GetRoll()
				trackTable[k].Color = v:GetColor()
				trackTable[k].TrackColor = v:GetActualTrackColor()
				if v:GetNodeType()==COASTER_NODE_LAUNCH then
					trackTable[k].LaunchKey=v:GetLaunchKey()
					trackTable[k].LaunchKeyString=v:GetLaunchKeyString()
					trackTable[k].LaunchSpeed=v:GetLaunchSpeed()
				end
			end

			trackTable.numnodes = #controller.Nodes
			trackTable.looped = tostring(controller:GetLooped())
			trackTable.name = name
			trackTable.author = client:GetName() // self:GetOwner():Name()
			trackTable.description = desc

			//Send the complete table to the client
			//The reason we generate the table on the server is that the client doesn't have all the information it needs
			//Not to mention, the client does not know about entities outside it's PVS, making saving long trains impossible
			net.Start("Coaster_transferInfo")
				net.WriteInt( TRANSFER_TRACK, 4 )
				net.WriteTable( trackTable )
			net.Send( client )

			if save == 1 then
				Msg("Saving " .. name .."...")
				//Convert the table into a format ready to be written to a file
				local towrite = util.TableToKeyValues(trackTable) 

				file.CreateDir("Rollercoasters/Server")

				file.Write("Rollercoasters/Server/" .. name .. ".txt", towrite)
				Msg("Done!\n")
			end
		end
	end )

end

if CLIENT then

	net.Receive("Coaster_transferInfo", function( length, client )

		local transferType = net.ReadInt( 4 )

		if transferType == TRANSFER_TRACKLIST then
			local TrackTable = net.ReadTable()

			if TrackTable then

				//and if the panel holding the listview is valid
				local panel = GetTabPanel( "saver" )
				if panel && panel.tracklist != nil then
					panel.tracklist:Clear()

					//Add each track name and info
					for key, value in pairs( TrackTable ) do
						if key and value then

							//Add specific info to panel
							local line = panel.tracklist:AddLine( value.name, value.author )

							line:SetValue( 3, "Rollercoasters/Server/" .. key )
							line:SetValue( 4, true ) //4 means it's serverside
						end
					end
				end
			end
		elseif transferType == TRANSFER_PREVIEW then
			local Filename = net.ReadString()
			local PreviewTrack = net.ReadTable()

			//Build the mesh
			GeneratePreview( PreviewTrack )

			//Associate that preview with that line
			local panel = GetTabPanel( "saver" )
			if panel && panel.tracklist != nil then
				local lines = panel.tracklist:GetLines()

				for k, v in pairs( lines ) do

					if ( v:GetValue( 1 ) .. ".txt" ) == Filename then 
						v.PreviewTable = PreviewTrack
						break;
					end
				end
			end
		elseif transferType == TRANSFER_TRACK then //The server is sending us the track it generated for us
			local tracktable = net.ReadTable()
			local name = tracktable.name

			local towrite = util.TableToKeyValues(tracktable) 

			file.CreateDir("Rollercoasters")

			file.Write("Rollercoasters/" .. name .. ".txt", towrite)
			GAMEMODE:AddNotify("Track \"" .. name .. "\" was saved successfully!", NOTIFY_GENERIC, 3 )
			//Update with the newly saved track
			UpdateTrackList()
		end
	end )

	local matrix = Matrix()
	hook.Add("PreDrawOpaqueRenderables", "DrawCoasterPreview", function()
		if !coaster_saver_preview_shoulddraw then return end

		if coaster_saver_preview_trackmesh && coaster_save_preview_material && coaster_saver_preview_trackcenter then
			local OrigPos = GetConVar("coaster_supertool_tab_saver_orig_spawn"):GetInt()==1


			if !matrix then matrix = Matrix() end
			render.SetMaterial(coaster_save_preview_material)

			local AimPos = LocalPlayer():GetEyeTrace().HitPos - coaster_saver_preview_trackcenter
			local AimAngle = LocalPlayer():GetAngles().y
			local curtime = CurTime() * 10

			if OrigPos then 
				AimPos = Vector( 0, 0, 0 ) 
				AimAngle = 0
			end

			//halp howdorotate
			matrix:Translate( AimPos )

			cam.PushModelMatrix( matrix )

				coaster_saver_preview_trackmesh:Draw()

			cam.PopModelMatrix()

			matrix:Translate( -AimPos )

		end

	end )
end

coastertabmanager.Register( UNIQUENAME, TAB )