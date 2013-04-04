if CLIENT then return end
local UnconstructedCoasters = {}
UnconstructedCoasters.ID = {}

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
end

local function GetControllerByID( coasterID )
	for k, v in pairs( UnconstructedCoasters[coasterID] ) do
		if v.IsController && v:IsController() then return v end
	end

	return nil
end

local function ReconstructCoaster(coasterID, owner, Controller )
	local unsortedNodes = GetNodesByID( coasterID )

	if !IsValid( Controller ) || !unsortedNodes || #unsortedNodes < 4 then return end -- Awww you suck
	
	if game.SinglePlayer() then
		Controller:SetOwner( Entity(1) ) -- If it's singleplayer, the player owns this save
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

		node:SetController( Controller )
		if !IsValid( Rollercoasters[coasterID] ) then
			Rollercoasters[coasterID] = node
			Rollercoasters[coasterID]:SetIsController(true)
			Rollercoasters[coasterID]:SetModel( "models/props_junk/PopCan01a.mdl" )

			//Call the hook telling a new coaster was created
			hook.Call("Coaster_NewCoaster", GAMEMODE, node )
		else
			//Nocollide the node with the main node so that the remover gun removes all nodes
			constraint.NoCollide( node, Rollercoasters[id], 0, 0 )
		end


		Controller:AddNodeSimple( node, owner )
	end

	Controller.Nodes[ #Controller.Nodes ]:SetModel( "models/props_junk/PopCan01a.mdl" )


	Controller:UpdateServerSpline()
	timer.Simple( 0.65, function()

		umsg.Start("Coaster_AddNode")
			umsg.Short( Controller:EntIndex() )
		umsg.End()

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
	local node = duplicator.GenericDuplicatorFunction( ply, data )
	local ID = node:GetCoasterID()

	if !UnconstructedCoasters[ ID ] then
		UnconstructedCoasters[ ID ] = {}
	end

	table.insert(UnconstructedCoasters[ ID ], node )

	local Controller = GetControllerByID( ID )

	-- A controller has been spawned, and we have the same number nodes spawned as when we were saved
	if IsValid( Controller ) && NumUnconstructedNodes( ID ) == Controller:GetNumCoasterNodes() then
		print("Beginning coaster rebuilding")
		ReconstructCoaster( ID, ply, Controller  )
		UnconstructedCoasters[ID] = nil
	end
end, "Data" )


local UnconstructedTrains = {}
UnconstructedTrains.ID = {}

local function FindNodeByID( trackid )
	for k, v in pairs( ents.FindByClass("coaster_node" ) ) do
		if IsValid( v ) && v:GetCoasterID() == trackid && v:IsController() then 
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
	print("Beginning train reconstruction")
	for id, tbl in pairs( UnconstructedTrains ) do
		ReconstructTrain( tbl )
	end
	UnconstructedTrains = {}
end

//Register some modifiers so we can save the carts to the track
duplicator.RegisterEntityModifier("cart_coaster_data", function(ply, ent, data)

	//print( data.CoasterID, data.Percent, data.Node, data.Index, data.TrainID )

	if data.CoasterID && data.Percent && data.Node && data.Index && data.TrainID then
		ent.Spawning = true 
		if !UnconstructedTrains[ data.TrainID ] then
			UnconstructedTrains[ data.TrainID ] = {}
		end

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
	end
end