include("autorun/sh_enums.lua")

local TRACK = TRACK && TRACK:Create()
if !TRACK then return end

TRACK.Name = "Blank Track"
TRACK.Description = "This track does nothing at all."
TRACK.PhysWidth = 30 //How wide the physics mesh should be
TRACK.SupportOverride = true //Don't draw the supports

trackmanager.Register( EnumNames.Tracks[COASTER_TRACK_BLANK], TRACK )

if !CLIENT then return end

TRACK.Material = Material( "coaster/track_metal_clean")

function TRACK:Generate( Controller )
	if !IsValid( Controller ) || !Controller:GetIsController() then return end

	local FakeMeshTable = {{ Mesh() }}
	-- Let's exit the thread, but give them our finalized sections too
	self:CoroutineCheck( Controller, 1, FakeMeshTable )
end

function TRACK:Draw( )
	-- nothing
end

