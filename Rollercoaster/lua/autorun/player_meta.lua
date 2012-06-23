local meta = FindMetaTable( "Player" )
if !meta then

	Msg("ALERT! Could not hook Player Meta Table\n")
	return

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
	
	self:EmitSound( table.Random( Screams ) )
end