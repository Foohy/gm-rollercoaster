local convar = CreateConVar("coaster_downloadtoclients", 1, { FCVAR_ARCHIVE }, "Tell clients to download rollercoaster-related models and materials (requires changelevel to take effect)")

if convar && convar:GetBool() then
	//SOUNDS
	resource.AddFile("sound/coaster_ride.wav")
	resource.AddFile("sound/coaster_chain.wav")
	resource.AddFile("sound/coaster_offdarailz.wav")
	resource.AddFile("sound/coaster_wind.wav")
	resource.AddFile("sound/coaster_sonic_the_carthog.mp3")

	//THANKS SUNABOUZU
	resource.AddFile("models/sunabouzu/coaster_base.mdl")
	resource.AddFile("materials/models/sunabouzu/coaster_base.vmt")
	resource.AddFile("materials/models/sunabouzu/coaster_base2.vmt")
	resource.AddFile("materials/models/sunabouzu/coaster_base3.vmt")
	resource.AddFile("models/sunabouzu/coaster_pole.mdl")
	resource.AddFile("materials/models/sunabouzu/coaster_pole.vmt")
	resource.AddFile("models/sunabouzu/coaster_pole_start.mdl")
	resource.AddFile("materials/models/sunabouzu/coaster_pole_start.vmt")

	resource.AddFile("materials/models/sunabouzu/sonic_the_carthog.vmt")
	resource.AddFile("models/sunabouzu/sonic_the_carthog.mdl")

	//MORE STUNABOUZU
	resource.AddFile("materials/sunabouzu/coaster_track.vmt")
	resource.AddFile("materials/sunabouzu/old_chain.vmt")

	//LOOK I'M LIKE SUNABOUZU
	resource.AddFile("materials/foohy/warning.vmt")
	resource.AddFile("materials/foohy/wood.vmt")

	//COASTER STUFF
	resource.AddFile("materials/coaster/cart.vmt")
	resource.AddFile("materials/coaster/remover.vmt")
	resource.AddFile("materials/coaster/save.vmt")
	resource.AddFile("materials/coaster/settings.vmt")
	resource.AddFile("materials/coaster/track.vmt")
	resource.AddFile("materials/coaster/track_metal.vmt")
	resource.AddFile("materials/coaster/track_metal_clean.vmt")
	resource.AddFile("materials/coaster/track_wooden_metalrails.vmt")
	resource.AddFile("materials/coaster/track_wooden_woodbeams.vmt")
	resource.AddFile("materials/coaster/wood.vmt")	
end
