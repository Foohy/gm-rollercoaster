local UnconstructedCoasters = {}
local CoasterIDConversions = {}

local function NumUnconstructedNodes( coasterID )
	local num = 0
	for k, v in pairs( UnconstructedCoasters[coasterID] ) do
		num = num + 1
	end

	return num
end

local function GetNodesByID( coasterID )
	local nodes = {}
	for k, v in pairs( UnconstructedCoasters[coasterID] ) do
		table.insert(nodes, v)
	end

	return nodes
end

local function GetNodeByOrder( num, unsortedNodes )
	for k, v in pairs( unsortedNodes ) do
		if IsValid( v ) && v:GetOrder() == num then return v end
	end

	return nil
end

local function GetControllerByID( coasterID )
	for k, v in pairs( UnconstructedCoasters[coasterID] ) do
		if v.GetIsController && v:GetIsController() then return v end
	end

	return nil
end

local function AllNodesAreValid( nodelist )
	local valid = true
	for k, v in pairs( nodelist ) do
		if !IsValid( v ) then 
			print("BAD NODE: " .. tostring( v ) .. " at index " .. k)
			valid = false
		end
	end

	return valid
end

local function NextCoasterID( curCoasterID )
	local expld = string.Explode("_", curCoasterID )
	local num = tonumber(expld[#expld]) or RealTime() //If it's required that this uses RealTime() for the number, the coasterID is probably terribly malformed for some reason

	//Go up!
	num = num + 1
	expld[#expld] = tostring( num )

	//re assemble the string
	return table.concat(expld, "_" ) 
end

local function GetOpenCoasterID( curID )
	for _, v in pairs( ents.FindByClass("coaster_node")) do
		if IsValid( v ) && v:GetCoasterID() == curID then
			return GetOpenCoasterID(NextCoasterID( curID ))
		end
	end

	return curID
end

local function ReconstructCoaster(coasterID, owner, Controller )
	local unsortedNodes = GetNodesByID( coasterID )

	if !IsValid( Controller ) || !unsortedNodes || #unsortedNodes < 4 then return end -- Awww you suck
	
	//Clear the controller's node table
	Controller.Nodes = {}

	if game.SinglePlayer() then
		local ply = #player.GetAll() > 0 && player.GetAll()[1] or Entity(1)
		Controller:SetOwner( ply ) -- If it's singleplayer, the player owns this save
	elseif IsValid( owner ) then
		Controller:SetOwner( owner )
	end


	for i=1, Controller:GetNumCoasterNodes() do
		local node = GetNodeByOrder( i, UnconstructedCoasters[coasterID] )
		if !IsValid( node ) then 
			print("WARNING: Node was missing when spawning. This is not good.") 
			print("Tried grabbing index: " .. i .. " from table:" ) 
			PrintTable(UnconstructedCoasters[coasterID]) 
			COASTERERRORTABLE = UnconstructedCoasters[coasterID] 
			continue 
		end
		//If this node had a physicsmesh, FAHGETABOUTIT
		node.PhysMesh = nil
		node:SetController( Controller )

		-- Fix colors from older saves
		local color = node:GetTrackColor()
		if (color.x > 1 || color.y > 1 || color.z > 1) then
			color = color / 255	
			node:SetTrackColor( color )
		end

		if !IsValid( Rollercoasters[coasterID] ) then
			Rollercoasters[coasterID] = node
			Rollercoasters[coasterID]:SetIsController(true)
			Rollercoasters[coasterID]:SetModel( "models/props_junk/PopCan01a.mdl" )

			//Call the hook telling a new coaster was created
			hook.Call("Coaster_NewCoaster", GAMEMODE, node )
		else
			//Nocollide the node with the main node so that the remover gun removes all nodes
			//constraint.NoCollide( node, Rollercoasters[id], 0, 0 )
		end

		Controller:AddNodeSimple( node, owner )
	end

	//Create a constraint with all the nodes so the duplicator picks them all up
	for k, v in pairs( Controller.Nodes ) do
		constraint.NoCollide( v, Controller, 0, 0 )
	end

	Controller.Nodes[ #Controller.Nodes ]:SetModel( "models/props_junk/PopCan01a.mdl" )

	Controller:UpdateServerSpline()

	//Add it to the user's undo list
	undo.Create("Saved Rollercoaster")
		undo.AddEntity( Controller )
		undo.SetPlayer( Controller:GetOwner() )
		undo.SetCustomUndoText("Undone Rollercoaster")
	undo.Finish()

	timer.Simple( 0.65, function()

		--umsg.Start("Coaster_AddNode")
		--	umsg.Short( Controller:EntIndex() )
		--umsg.End()

		//Force the client to update the spline
		if IsValid( Controller ) then
			umsg.Start("Coaster_invalidateall")
				umsg.Entity( Controller )
			umsg.End()
		end
	end )

	UnconstructedCoasters[coasterID] = nil
end

duplicator.RegisterEntityClass("coaster_node", function( ply, data )
	-- We need to modify some things to make them backwards compatible
	-- SetNodeType used to be called SetType, so if SetType exists in old saves and its a valid number, give it a shot
	if (data.DT && type(data.DT.Type) == "number" && data.DT.Type <= #EnumNames.Nodes) then
		data.DT.NodeType = data.DT.Type
	end

	local node = duplicator.GenericDuplicatorFunction( nil, data )
	local ID = node:GetCoasterID()

	-- Check if anyone has any objections
	local res = hook.Run("Coaster_ShouldCreateNode", ID, ply )
	if res != nil && res==false then 
		if IsValid( node ) then node:Remove() end
		return
	end

	-- Make completely sure this list is empty before we start storing stuff in it
	-- Kinda hacky but there isn't really a nice hook to clear it elsewhere
	if CurTime() != UnconstructedCoasters.BuildTime then
		UnconstructedCoasters = {}
		UnconstructedCoasters.BuildTime = CurTime()
	end

	if !UnconstructedCoasters[ ID ] then
		UnconstructedCoasters[ ID ] = {}
	end

	table.insert(UnconstructedCoasters[ ID ], node )

	local Controller = GetControllerByID( ID )

	-- A controller has been spawned, and we have the same number nodes spawned as when we were saved
	if IsValid( Controller ) && NumUnconstructedNodes( ID ) == Controller:GetNumCoasterNodes() && AllNodesAreValid(UnconstructedCoasters[ ID ]) then

		//Retrieve a new unique ID
		local newID = GetOpenCoasterID( Controller:GetCoasterID() )

		for _, v in pairs( UnconstructedCoasters[ID] ) do
			v:SetCoasterID( newID )
		end

		CoasterIDConversions[ID] = newID

		//Move them over into a section with the new id
		UnconstructedCoasters[newID] = UnconstructedCoasters[ID]
		UnconstructedCoasters[ID] = nil

		print("Beginning coaster rebuilding")
		ReconstructCoaster( newID, ply, Controller  )
		UnconstructedCoasters[newID] = nil
	end
end, "Data" )


local UnconstructedTrains = {}
UnconstructedTrains.ID = {}

local function FindNodeByID( trackid )
	for k, v in pairs( ents.FindByClass("coaster_node" ) ) do
		if IsValid( v ) && v:GetCoasterID() == trackid && v:GetIsController() then 
			return v
		end
	end
end

local function FindValidDataTable( traintbl )
	for k, v in pairs( traintbl ) do
		if IsValid ( v ) && v.TrainDataLoad && v.TrainDataLoad.CoasterID then
			return v.TrainDataLoad
		end
	end

	return nil
end

local function FindNodeByUnsortedTable( traintbl )
	for k, v in pairs( traintbl ) do
		if IsValid ( v ) && v.TrainDataLoad && v.TrainDataLoad.CoasterID then
			return FindNodeByID(v.TrainDataLoad.CoasterID)
		end
	end

	return nil
end

local function ConstructCartTable( traintbl )
	if RCCartGroups == nil then RCCartGroups = 1 end

	if !_G["CartTable_" .. RCCartGroups] then
		_G["CartTable_" .. RCCartGroups] = {}
	end
	local cartgroup = _G["CartTable_" .. RCCartGroups]
	RCCartGroups = RCCartGroups + 1

	local count = table.Count( traintbl )
	for i=1, count do
		if !traintbl[i] || !traintbl[i].TrainDataLoad then continue end 
		cartgroup[traintbl[i].TrainDataLoad.Index] = traintbl[i]
	end

	return cartgroup
end

local function ReconstructTrain( traintbl )
	if !traintbl || #traintbl < 1 then return end 
	local Controller = FindNodeByUnsortedTable( traintbl )
	if !IsValid( Controller ) then return end

	local CartTable = ConstructCartTable(traintbl)

	for k, v in pairs( traintbl ) do
		if !IsValid( v ) then continue end 
		v.Controller = Controller
		v.CartTable = CartTable
		v.Spawning = false
		v:GetPhysicsObject():EnableMotion( true )
		v:GetPhysicsObject():Wake()
	end

	RollercoasterUpdateCartTable(CartTable)
end

local function DelayedSpawn()
	//note that the id is NOT the coasterID, it's a unique identifier for the train
	for id, tbl in pairs( UnconstructedTrains ) do
		ReconstructTrain( tbl )
	end
	UnconstructedTrains = {}
	CoasterIDConversions = {}
end

//Register some modifiers so we can save the carts to the track
duplicator.RegisterEntityModifier("cart_coaster_data", function(ply, ent, data)

	//print( data.CoasterID, data.Percent, data.Node, data.Index, data.TrainID )

	if data.CoasterID && data.Percent && data.Node && data.Index && data.TrainID then
		ent.Spawning = true 
		if !UnconstructedTrains[ data.TrainID ] then
			UnconstructedTrains[ data.TrainID ] = {}
		end

		//Overwrite the coasterid in the data
		data.CoasterID = CoasterIDConversions[data.CoasterID] or data.CoasterID 

		ent:GetPhysicsObject():EnableMotion( false )
		ent.CurSegment = data.Node
		ent.CoasterID = data.CoasterID 
		ent.Percent = data.Percent
		ent.Velocity = data.Velocity or 4
		ent.PhysShadowControl.secondstoarrive = 0.00001
		ent.TrainDataLoad = data 

		table.insert(UnconstructedTrains[ data.TrainID ], ent )

		duplicator.StoreEntityModifier( ent, "cart_coaster_data", data )

		timer.Create("AssignCartsAfterLoad", 1, 1, function()
			DelayedSpawn()
		end )
	end
end)

//Override SetPersistent so that all of the other nodes are also set to be persistent
local meta = FindMetaTable("Entity")
local oldSetPersistent = meta.SetPersistent 
function meta:SetPersistent( bool )
	oldSetPersistent( self, bool )

	if (self:GetClass() == "coaster_node" ) || self:GetClass() == "coaster_physmesh" then
		for k, v in pairs( ents.FindByClass("coaster_node")) do
			if IsValid( v ) && v.GetCoasterID && v:GetCoasterID() == self:GetCoasterID() then
				oldSetPersistent( v, bool )
			end
		end

		for k, v in pairs( ents.FindByClass("coaster_physmesh")) do
			if IsValid( v ) && v.GetCoasterID && v:GetCoasterID() == self:GetCoasterID() then
				oldSetPersistent( v, bool )
			end
		end
	end
end