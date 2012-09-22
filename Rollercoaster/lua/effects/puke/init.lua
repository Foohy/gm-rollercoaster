EFFECT.Mat = Material("effects/blood_core")

local pukesounds = {	
	Sound("npc/zombie/zombie_pain1.wav"),
	Sound("npc/zombie/zombie_pain3.wav")
}


function EFFECT:Init( data )
	self.Player = data:GetEntity();

	if !IsValid(self.Player) then return end

	self.Length = CurTime() + 1.25;
	self.Emitter = ParticleEmitter( self.Player:GetPos() );
	
	sound.Play( table.Random(pukesounds), self.Player:GetShootPos(), 100, 100 );
end

local function CollideCallback( particle, pos, normal )
	// decal.
	util.Decal( "BeerSplash", pos + normal, pos - normal );
	
	// make fatter
	particle:SetStartSize( 24 );
	particle:SetEndSize( 16 );
	
end 

// think
function EFFECT:Think( )
	if ( !IsValid( self.Player ) ) then
	
		return false;
		
	end
	local pos = self.Player:GetShootPos();
	if( self.Player == LocalPlayer() ) then
		pos = pos + Vector( 0, 0, -10 ) + self.Player:GetAimVector() * 24;
	end
	
	// create particle emitter.
	//local emitter = ParticleEmitter( pos );
	
	// create a particle.
	local particle = self.Emitter:Add( "effects/blood_core", pos );
	particle:SetVelocity( ( self.Player:GetAimVector() + ( VectorRand() * 0.1 ) ) * math.random( 120, 350 ) );
	particle:SetDieTime( 3.25 );
	particle:SetStartAlpha( 255 );
	particle:SetEndAlpha( 128 );
	particle:SetStartSize( math.Rand( 12, 16 ) );
	particle:SetEndSize( math.Rand( 8, 12 ) );
	particle:SetRoll( 0 );
	particle:SetRollDelta( 0 );
	particle:SetColor( 128, 80, 0 );
	particle:SetCollide( true );
	particle:SetBounce( 0.2 );
	particle:SetGravity( Vector( 0, 0, -400 ) );
	//particle:SetAngleVelocity( Angle( math.random( -100, 100 ), math.random( -100, 100 ), math.random( -100, 100 ) ) );
	particle:SetCollideCallback( CollideCallback );
	
	// finalize te emitter.
	//emitter:Finish();
	
	// trace, decal.
	local trace = {
		start = pos,
		endpos = pos + self.Player:GetAimVector() * 128,
		filter = ent,
	};
	local tr = util.TraceLine( trace );
	if( tr.Hit && !tr.HitSky ) then
		util.Decal( "BeerSplash", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal );
	end
	
	if( self.Length <= CurTime() ) then self.Emitter:Finish(); end
	
	return ( self.Length > CurTime() );
end

// render.
function EFFECT:Render( )
end
