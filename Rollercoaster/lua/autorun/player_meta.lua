local meta = FindMetaTable( "Player" )
if !meta then

	Msg("ALERT! Could not hook Player Meta Table\n")
	return

end

//Return number of active carts this person has spawned
function meta:NumActiveCarts()
	local numCarts = 0

	for _, v in pairs(ents.FindByClass("coaster_cart")) do
		if !v.IsDummy && v.Owner == self then 
			numCarts = numCarts + 1
		end
	end

	return numCarts
end

//Return number of independent rollercoasters this person has spawned
function meta:NumCoasters()
	local numCoasters = 0
	if Rollercoasters then
		for _, v in pairs(Rollercoasters) do
			if IsValid( v ) && v:GetOwner() == self then
				numCoasters = numCoasters + 1
			end
		end
	end

	return numCoasters
end

//Return total amount of nodes this person has spawned
function meta:NumCoasterNodes()
	local numNodes = 0

	if Rollercoasters then
		for _, v in pairs(Rollercoasters) do
			if IsValid( v ) && v:GetOwner() == self && v.Nodes then
				numNodes = numNodes + (#v.Nodes - 2) //Don't count the controller and very last node
			end
		end
	end

	return numNodes
end

function meta:Puke()
	self:ViewPunch( Angle( -5, 0, 0 ) )
	
	local edata = EffectData()
	edata:SetOrigin( self:EyePos() )
	edata:SetEntity( self )

	util.Effect( "puke", edata, true, true )
end

function meta:Scream()
	local Screams = {
		"vo/npc/male01/help01.wav",
		"vo/npc/male01/no02.wav",
		"vo/npc/male01/ohno.wav",
		"vo/npc/male01/pain01.wav",
		"vo/npc/male01/pain07.wav",
		"vo/npc/male01/pain08.wav",
		"vo/npc/male01/startle01.wav",
		"vo/npc/male01/startle02.wav",
		"vo/npc/male01/yeah02.wav",
		"vo/npc/Barney/ba_yell.wav",
		"vo/npc/female01/ohno.wav",
		"vo/npc/female01/startle01.wav",
		"vo/npc/female01/yeah02.wav"
	}

	self:ViewPunch( Angle( -5, 0, 0 ) )
	self:EmitSound( table.Random( Screams ), 100, 100 )
end

function meta:InRollercoaster()
	if !IsValid( self ) || !self:InVehicle() then return false end

	local pod = self:GetVehicle()
	if !IsValid( pod ) || !IsValid( pod:GetParent() ) || pod:GetParent():GetClass() != "coaster_cart" then return false end

	return true
end