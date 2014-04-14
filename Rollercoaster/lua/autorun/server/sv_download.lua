-- MANAGE DOWNLOADING TO CLIENTS
-- 0 = Don't download
-- 1 = Download via workshop
-- 2 = Dwnload via resource.AddFile

COASTER_DOWNLOAD_NONE 		= 0
COASTER_DOWNLOAD_WORKSHOP 	= 1
COASTER_DOWNLOAD_CLASSIC 	= 2

COASTER_WORKSHOPID = "104508032"
local convar = CreateConVar("coaster_downloadtoclients", 1, { FCVAR_ARCHIVE }, "Tell clients to download rollercoaster-related models and materials (requires changelevel to take effect)\n\t0 = Don't download\n\t1 = Download via workshop\n\t2 = Download via the traditional way (resource.AddFile)")

if not convar then return end 
local enum = convar:GetInt()
if enum == COASTER_DOWNLOAD_WORKSHOP then
	resource.AddWorkshop(COASTER_WORKSHOPID)
elseif enum == COASTER_DOWNLOAD_CLASSIC then
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
