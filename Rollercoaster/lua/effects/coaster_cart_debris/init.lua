function EFFECT:Init( data )

	self.DieTime = CurTime() + 0.25

	local normal = data:GetNormal() * -1
	local pos = data:GetOrigin()

	local numdebris = math.random( 5, 6 )
	local DebrisModels = {
		Model( "models/gibs/manhack_gib01.mdl" ), Model( "models/gibs/manhack_gib02.mdl" ),
		Model( "models/gibs/manhack_gib04.mdl" ), Model( "models/gibs/metal_gib1.mdl" ),
		Model( "models/gibs/metal_gib2.mdl" ), Model( "models/gibs/metal_gib3.mdl" ),
		Model( "models/gibs/metal_gib4.mdl" ), Model( "models/Gibs/Glass_shard.mdl" ),
		Model( "models/Gibs/Glass_shard02.mdl" ), Model( "models/Gibs/Glass_shard03.mdl" )
	}

	for i=0, numdebris do

		local debris = ClientsideModel( DebrisModels[ math.random( 1, #DebrisModels ) ], RENDERGROUP_OPAQUE )
		if IsValid( debris ) then
			debris:SetPos( self:GetPos() + Vector( 0, 0, 10 ) )
			debris:SetMaterial( "models/props_pipes/GutterMetal01a" )

			debris:PhysicsInitBox( Vector( -6, -6, -6 ), Vector( 6, 6, 6 ) )
			debris:SetCollisionBounds( Vector( -6, -6, -6 ), Vector( 6, 6, 6 ) )

			if math.random( 1, 3 ) == 1 then
				debris:SetColor( Color( 255, 125, 0, 255 ) )
			else
				debris:SetColor( Color( 215, 0, 0, 255 ) )
			end

			local phys = debris:GetPhysicsObject()
			if IsValid( phys ) then

				local force = 30
				phys:AddVelocity( Vector( math.random( -force, force ), math.random( -force, force ), math.random( 30, 80 ) ) )
				phys:AddAngleVelocity( Angle( 1500, 0, 0 ) )

			end

			timer.Simple( math.Rand( 4, 6 ), debris.Remove, debris )
		end

	end

end

function EFFECT:Think() return false end

function EFFECT:Render() end
