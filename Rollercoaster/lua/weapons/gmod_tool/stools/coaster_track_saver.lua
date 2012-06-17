TOOL.Category   = "Rollercoaster"
TOOL.Name       = "Track Saver"
TOOL.Command    = nil
TOOL.ConfigName	= nil

TOOL.ClientConVar["id"] = "1"

TOOL.ClientConVar["elevation"] = "500"
TOOL.ClientConVar["bank"] = "0"

TOOL.ClientConVar["trackchains"] = "0"
TOOL.ClientConVar["relativeroll"] = "0"

TOOL.GhostModel = Model("models/Combine_Helicopter/helicopter_bomb01.mdl")
TOOL.WaitTime	= 0 //Time to wait to make sure the dtvars are updated
TOOL.CoolDown 	= 0 //For some reason, LeftClick is called four times when pressed once. :/

coaster_saver_ClipboardTrack = {} //The coaster track loaded into the 'clipboard', to be saved or loaded
coaster_saver_selectedfilename = "none"

if SERVER then
	util.AddNetworkString("Coaster_transferInfo")
end

function TOOL:LeftClick(trace)
	if CurTime() < self.CoolDown then return end
	if CLIENT || SinglePlayer() then
		self:SpawnTrack()
		self.CoolDown = CurTime() + .25

		return true
	end
end

function TOOL:RightClick(trace)
	local ply   = self:GetOwner()
	
	trace = {}
	trace.start  = ply:GetShootPos()
	trace.endpos = trace.start + (ply:GetAimVector() * 99999999)
	trace.filter = ply
	trace = util.TraceLine(trace)
	
	if IsValid( trace.Entity ) && trace.Entity:GetClass() == "coaster_node" then
		if IsValid( trace.Entity:GetController() ) && CLIENT then
			local Controller = trace.Entity:GetController()
			coaster_saver_ClipboardTrack = {} //This will be the table holding all of the information we'll need to later create the coaster

			for k, v in pairs( Controller.Nodes ) do
				coaster_saver_ClipboardTrack[k] = {}
				coaster_saver_ClipboardTrack[k].Pos = tostring(v:GetPos())
				coaster_saver_ClipboardTrack[k].Ang = tostring(v:GetAngles())
				coaster_saver_ClipboardTrack[k].Type = v:GetType()
				coaster_saver_ClipboardTrack[k].Roll = v:GetRoll()
				coaster_saver_ClipboardTrack[k].Color = v:GetColor()
			end

			coaster_saver_ClipboardTrack.numnodes = #Controller.Nodes
			coaster_saver_ClipboardTrack.looped = tostring(Controller:Looped())
		end

		return true
	end
end

function TOOL:Reload(trace)

end

function TOOL:Holster()
	 coaster_track_creator_HoverEnts = nil
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
				SelectAllNodes( controller, Color( 180 - math.random( 0, 80 ), 220 - math.random( 0, 50 ), 255, 255 ) )
			end
		else 
			coaster_track_creator_HoverEnts = nil
		end

	end
end

function TOOL:ValidTrace(trace)

end

function OpenCoasterSaveMenu()
	print("heyo")
	local form = vgui.Create( "DFrame" )
	form:SetSize( 250, 276 )
	form:SetTitle(" ")
	form:Center()
	form:SetVisible( true )
	form:SetDraggable( true )
	form:ShowCloseButton( false )
	form:MakePopup()
	form.Paint = function() draw.RoundedBox( 8, 0, 0, form:GetWide(), form:GetTall(), Color( 0,0,0,150)) end //Make it invisible
	
	local panel = vgui.Create("DForm", form)
	//local x, y = form:GetSize()
	//panel:SetSize( x - 4, y - 10 )
	//panel:SetPos( 2, -7)
	local x = 250
	local y = 288
	panel:SetSize( form:GetSize())
	//panel:Center()
	panel:SetPos( 0, 12)
	//local px, py = panel:GetPos()
	//panel:SetPos( px - (x / 2), py - (y / 2) )
	panel:SetName("Save Rollercoaster")

	/*
	panel:Center()
	panel:SetSize( 500, 700 )
	panel:SetTitle( "Save rollercoaster" )
	panel:SetVisible( true )
	panel:SetDraggable( true )
	panel:ShowCloseButton( true )
	panel:MakePopup()
	*/

	local LabelName = vgui.Create("Label", panel)
	LabelName:SetText("Name:")
	panel:AddItem( LabelName )


	local DName = vgui.Create("DTextEntry")
	DName.Label = "#Name"
	DName:SetParent( panel )
	panel:AddItem( DName )
	panel.DName = DName

	local LabelDesc = vgui.Create("Label", panel)
	LabelDesc:SetText("Description:")
	panel:AddItem( LabelDesc )

	local DDesc = vgui.Create("DTextEntry")
	DDesc.Label = "#Description"
	DDesc:SetMultiline( true )
	DDesc:SetTall(84)
	DDesc:SetParent( panel )
	panel:AddItem( DDesc )
	panel.DDesc = DDesc

	//local btnCancel = panel:Button( "Cancel")
	//btnCancel.DoClick = function() panel:Close() end
	local btnCancel = vgui.Create("Button")
	btnCancel:SetText("Cancel")
	btnCancel.DoClick = function() form:Close() end
	panel:AddItem( btnCancel )

	local btnSave = vgui.Create("Button")
	btnSave:SetText("Save")
	btnSave.DoClick = function() SaveTrack(DName:GetValue(), DDesc:GetValue()); form:Close(); surface.PlaySound("garrysmod/content_downloaded.wav") end
	panel:AddItem( btnSave )

	//panel:AddControl("Button",	 {Label = "Cancel", Description = "Save the currently copied track", DoClick = function() panel:Close() end}) 
	//panel:AddControl("Button",	 {Label = "Save", Description = "Save the currently copied track", DoClick = function() SaveTrack(); panel:Close() end}) 

	//local btnSave = panel:Button( "Save")
	//btnSave.DoClick = function() SaveTrack(); panel:Close() end

	//panel:AddControl("Button",	 {Label = "Save", Description = "Save the currently copied track", Command = "coaster_track_saver_save"}) 
end

function OpenCoasterUploadMenu()
	//Set up our form
	local panel = controlpanel.Get("coaster_track_saver")

	local form = vgui.Create( "DFrame" )
	form:SetSize( 250, 312 )
	form:SetTitle(" ")
	form:Center()
	form:SetVisible( true )
	form:SetDraggable( true )
	form:ShowCloseButton( false )
	form:MakePopup()
	form.Paint = function() draw.RoundedBox( 8, 0, 0, form:GetWide(), form:GetTall(), Color( 0,0,0,150)) end //Make it invisible

	local panel = vgui.Create("DForm", form, "coaster_track_saver_uploadpanel")
	panel:SetSize( form:GetSize())
	//panel:Center()
	panel:SetPos( 0, 12)
	//local px, py = panel:GetPos()
	//panel:SetPos( px - (x / 2), py - (y / 2) )
	panel:SetName("Upload Track to Server")
	print(panel:GetSize())

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

		toolpanel = controlpanel.Get("coaster_track_saver")
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

function SaveTrack(name, desc)
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
	end
end

function UpdateTrackList()
	local panel = controlpanel.Get("coaster_track_saver")
	if panel && panel.tracklist != nil then
		print("Updating local track list...")
		panel.tracklist:Clear()

		if SinglePlayer() then //update from locally saved files
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
			RunConsoleCommand("coaster_track_saver_requesttracklist")
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
	net.WriteTable( tracklist )
	net.Send( ply )


end

usermessage.Hook("Coaster_fileexists", function( um )
	local exists = um:ReadBool()
	local file = um:ReadString()

	local panel = controlpanel.Get("coaster_track_saver_uploadpanel")
end )

function LoadSelectedTrack()
	local panel = controlpanel.Get("coaster_track_saver")
	if panel && panel.tracklist != nil then
		print("Loading track...")
		local line = nil
		local num = panel.tracklist:GetSelectedLine()
		if num then
			line = panel.tracklist:GetLine( num )
		else
			return 
			print("Failed to load track - No selected track. (" .. tostring( num ) .. ")")
		end

		if line then
			//if SinglePlayer() then
			//	print( line:GetValue( 3 ))
			//	local contents = file.Read( line:GetValue(3) ) //Is there a way to get the full file path of the file?
			//	local tbl = util.KeyValuesToTable( contents )

			//	coaster_saver_ClipboardTrack = tbl //Load the table into our clipboard TODO: make a visualize clipboard function
			//else
				coaster_saver_selectedfilename = line:GetValue( 1 ) .. ".txt"
				print( "selected: " .. tostring(line:GetValue( 1 )))

				print(coaster_saver_selectedfilename)
			//end
		else
			return
			print("Failed to load track - Line was nil")
		end
	end
end

usermessage.Hook("Coaster_spawntrack_sp", function(um) 
	RunConsoleCommand( "coaster_track_saver_spawntrack", coaster_saver_selectedfilename, um:ReadShort() or 1)
	print("Building \"" .. coaster_saver_selectedfilename .. "\"")
end )

function TOOL:SpawnTrack()
	if SinglePlayer() then //I'm seriously sending a usermessage to the client, who is the host. WHY IS LEFTCLICK NOT CALLED ON THE CLIENT IN SINGLEPLAYER
		umsg.Start("Coaster_spawntrack_sp")
			umsg.Short(self:GetClientNumber("ID"))
		umsg.End()
	else
			RunConsoleCommand( "coaster_track_saver_spawntrack", coaster_saver_selectedfilename, self:GetClientNumber("ID"))
			print("Building \"" .. coaster_saver_selectedfilename .. "\"")
	end
	//print(coaster_saver_selectedfilename)
	//PrintTable(coaster_saver_ClipboardTrack)
	//print(coaster_saver_ClipboardTrack["name"] )
	//if coaster_saver_ClipboardTrack && coaster_saver_ClipboardTrack["name"] != nil then
		//OH BOY
		//print("Building \"" .. coaster_saver_ClipboardTrack["name"] .. "\"")

		//Tell the server we want to spawn the track
		
		//if !SinglePlayer() && coaster_saver_selectedfilename != nil && CLIENT then	
			//RunConsoleCommand( "coaster_track_saver_spawntrack", coaster_saver_selectedfilename, self:GetClientNumber("ID"))
			//print("Building \"" .. coaster_saver_selectedfilename .. "\"")
		//elseif SinglePlayer() && SERVER then
		//	RunConsoleCommand( "coaster_track_saver_spawntrack_sp", coaster_saver_selectedfilename, self:GetClientNumber("ID"))
		//end
	//else
	//	print("No track in clipboard!")
	//end
end

function TOOL.BuildCPanel(panel)	
	local tracklist = vgui.Create("DListView")
	tracklist:SetParent( panel )
	tracklist:SetMultiSelect( false )
	tracklist:AddColumn("Track Name")
	tracklist:AddColumn("Author")
	//tracklist:AddColumn("Filepath")
	tracklist:SetTall( 200 )

	panel:AddItem( tracklist )
	panel.tracklist = tracklist

	UpdateTrackList()

	local btnLoad = panel:Button("Load Selected")
	btnLoad.DoClick = function() LoadSelectedTrack() end
	btnLoad:SetWide( (panel:GetWide() / 2) - 5 )
	btnLoad:AlignLeft()

	local btnRefresh = panel:Button("Refresh")
	btnRefresh.DoClick = function() UpdateTrackList() end
	btnRefresh:SetWide( (panel:GetWide() / 2) - 5 )
	btnRefresh:MoveRightOf( btnLoad, 10 )
	btnRefresh:AlignRight()

	if !SinglePlayer() then
		panel:Button("Upload...", "coaster_track_saver_uploadpanel")
	end
	//btnRefresh:SetWide( (panel:GetWide() / 2) - 5 )
	//btnRefresh:MoveRightOf( btnLoad, 10 )
	//btnRefresh:AlignRight()

	//panel:AddControl("Button",	 {Label = "Load Selected", Command = "coaster_track_saver_openselected"}) 
	//panel:AddControl("Button",	 {Label = "Refresh", DoClick = self.UpdateTrackList}) 
	panel:AddControl("Slider",   {Label = "Spawn ID: ",    Description = "The ID of the specific rollercoaster (Change the ID if you want to make a seperate coaster)",       Type = "Int", Min = "1", Max = "8", Command = "coaster_track_saver_id"})

	panel:AddControl("CheckBox", {Label = "Spawn at original position: ", Command = "coaster_track_creator_relativeroll"})
	//panel:AddControl("Button",	 {Label = "BUILD COASTER (CAUTION WEEOOO)", Description = "Build the current rollercoaster with a pretty mesh track. WARNING FREEZES FOR A FEW SECONDS.", Command = "update_mesh"})
	//Begin save section
	//local divider = vgui.Create("DHorizontalDivider")
	//panel:AddControl("divider")
	//panel:AddControl("Label", { Label = "__________________________________"})
	local Seperator = vgui.Create("Label", panel)
	Seperator:SetText("______________________________________________")
	panel:AddItem( Seperator )

	local btnSave = panel:Button("Save Rollercoaster")
	btnSave.DoClick = function() OpenCoasterSaveMenu() end

	//panel:AddControl("Button",	 {Label = "Save Rollercoaster", Description = "Save the currently copied track", DoClick = function() OpenCoasterSaveMenu() end }) 

	panel:AddControl( "Header", { Text = "#Tool_coaster_track_saver_name", Description = "#Tool_track_saver_desc" }  )
end

concommand.Add("coaster_track_saver_uploadpanel", function()
	OpenCoasterUploadMenu()
end)

//Activate things on the server (not really enough to govern a net function)
if SERVER then
	local controllernode = nil
	function SpawnNode( ply, nodeinfo, i, num, filename, id, looped)

		local pos = Vector( nodeinfo.pos )
		local ang = Angle( nodeinfo.ang )
		local color = Color( nodeinfo.color.r, nodeinfo.color.g, nodeinfo.color.b )

		local node = CoasterManager.CreateNodeSimple(id, pos, ang )
		node:SetRoll( nodeinfo.roll )

		node:SetType( nodeinfo.type )
		node:SetColor( color  )

		node.Filename = filename //Prevent duplicates of the coaster to be spawned

		if i==1 then //Controller node is _always_ the first node
			controllernode = node 
			controllernode:SetLooped( looped )
			controllernode:SetOwner( ply )
		end

		if i==num && IsValid( controllernode ) then
			node:SetModel( "models/props_junk/PopCan01a.mdl" ) //Hide very last node

			controllernode:UpdateServerSpline()
			timer.Simple( 0.2 , function() //Final delay in case any nodes were missed
				umsg.Start("Coaster_AddNode")
					umsg.Short( controllernode:EntIndex() )
				umsg.End()
			end )

			undo.Create("Saved Rollercoaster")
				undo.AddEntity( controllernode )
				undo.SetPlayer( ply )
				undo.SetCustomUndoText("Undone \"" .. filename .. "\"")
			undo.Finish()
		end

		//Force the server and client to update the spline
		if IsValid( controllernode ) then
			controllernode:UpdateServerSpline()

			umsg.Start("Coaster_AddNode")
				umsg.Short( controllernode:EntIndex() )
			umsg.End()
		end
	end

	concommand.Add("coaster_track_saver_requesttracklist", function(ply, cmd, args)
		RequestTrackList(ply)
	end)

	concommand.Add("coaster_track_saver_spawntrack", function(ply, cmd, args)
		local filename = args[1]
		local id = math.Round(tonumber(args[2]) ) or 9

		local directory ="Rollercoasters/Server/"
		if SinglePlayer() then directory = "Rollercoasters/" end

		if file.Exists(directory .. filename, "DATA") then
			//Check if the track exists (Temporary until tracks can be spawned via toolgun)
			for k, v in pairs( ents.FindByClass("coaster_node") ) do
				if v.Filename == filename then
					print("Track: " .. filename .. " already spawned! Aborting...")
					return
				end
			end

			//Load the file
			local contents = file.Read( directory .. filename )
			local tbl = util.KeyValuesToTable( contents )

			if tbl then
				print("Spawning coaster " .. filename )
				//print(tbl.numnodes)
				//local controllernode = nil

				if IsValid( Rollercoasters[id] ) then Rollercoasters[id]:Remove() end

				for i=1, tbl.numnodes do
					local nodeinfo = tbl[i]
					local looped = tbl.looped == "true"

					//Please forgive me.
					//Spawning multiple entities in the same frame really fucked something on the client
					//The node was unable to be grabbed by the physgun, despite any settings applied to it
					//On the bright side, it makes a neat spawn effect
					timer.Simple( i / 10, function()
						SpawnNode( ply, nodeinfo, i, tbl.numnodes, filename, id, looped)
					end )
					/*
					local pos = Vector( nodeinfo.pos )
					local ang = Angle( nodeinfo.ang )

					local node = CoasterManager.CreateNodeSimple(1, pos, ang )
					node:SetRoll( nodeinfo.roll )
					node:SetChains( nodeinfo.chains=="true" )
					node:SetColor( nodeinfo.color )
					node:SetOwner( ply )
					*/
					//if i==1 then controllernode = node end
				end

			end
		end
	end )
end

//Use net library to send local file to server (If I may add, holy shit I love the net library)
if SERVER then

	net.Receive("Coaster_transferInfo", function( length, client )
		local Track = net.ReadTable()
		print("Received track " .. Track["name"] .. " from " .. client:GetName())

		local towrite = util.TableToKeyValues(Track) 

		local dirlist = file.FindDir("Rollercoasters/Server", "DATA" )
		if #dirlist < 1 then
			file.CreateDir("Rollercoasters/Server")
			print("Creating new directory..")
		end

		file.Write("Rollercoasters/Server/" .. Track["name"] .. ".txt", towrite)

		//Update them with the newest files
		RequestTrackList(client)
	end )

end

if CLIENT then

	net.Receive("Coaster_transferInfo", function( length, client )
		local TrackTable = net.ReadTable()

		if TrackTable then
			//and if the panel holding the listview is valid
			local panel = controlpanel.Get("coaster_track_saver")
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
	end )

end

if CLIENT then

	language.Add( "Tool_coaster_track_saver_name", "Save/Load Tracks" )
	language.Add( "Tool_coaster_track_saver_desc", "Save coasters for later or load already saved coasters." )
	language.Add( "Tool_coaster_track_saver_0", "Right click on a coaster to select it to save. Left click to spawn a loaded coaster." )

end

