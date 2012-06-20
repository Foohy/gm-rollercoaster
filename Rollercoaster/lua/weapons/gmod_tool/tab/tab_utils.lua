function GetClientNumber( self, convar, tool)
	return tool:GetOwner():GetInfoNum("coaster_supertool_tab_" .. self.UniqueName .. "_" .. convar, 0 )
end

function GetClientInfo( self, convar, tool)
	return tool:GetOwner():GetInfo("coaster_supertool_tab_" .. self.UniqueName .. "_" .. convar )
end

SupertoolTabPanels = {}
function RegisterTabPanel( panel, name )
	SupertoolTabPanels[ name ] = panel
end

function GetTabPanel( name )
	return SupertoolTabPanels[ name ]
end

/*****************************************************************************
================================ GHOST ENTITY ================================
******************************************************************************/

--[[---------------------------------------------------------
   Starts up the ghost entity
   The most important part of this is making sure it gets deleted properly
-----------------------------------------------------------]]
function MakeGhostEntity( tab, model, pos, angle )

	util.PrecacheModel( model )
	
	-- We do ghosting serverside in single player
	-- It's done clientside in multiplayer
	if (SERVER && !SinglePlayer()) then return end
	if (CLIENT && SinglePlayer()) then return end
	
	-- Release the old ghost entity
	ReleaseGhostEntity( tab )
	
	-- Don't allow ragdolls/effects to be ghosts
	if (!util.IsValidProp( model )) then return end
	
	if ( CLIENT ) then
		tab.GhostEntity = ents.CreateClientProp( model )
	else
		tab.GhostEntity = ents.Create( "prop_physics" )
	end
	
	-- If there's too many entities we might not spawn..
	if (!tab.GhostEntity:IsValid()) then
		tab.GhostEntity = nil
		return
	end
	
	tab.GhostEntity:SetModel( model )
	tab.GhostEntity:SetPos( pos )
	tab.GhostEntity:SetAngles( angle )
	tab.GhostEntity:Spawn()
	
	tab.GhostEntity:SetSolid( SOLID_VPHYSICS );
	tab.GhostEntity:SetMoveType( MOVETYPE_NONE )
	tab.GhostEntity:SetNotSolid( true );
	tab.GhostEntity:SetRenderMode( RENDERMODE_TRANSALPHA )
	tab.GhostEntity:SetColor( Color( 255, 255, 255, 150 ) )
	
end

--[[---------------------------------------------------------
   Starts up the ghost entity
   The most important part of this is making sure it gets deleted properly
-----------------------------------------------------------]]
function StartGhostEntity( tab, ent )

	-- We can't ghost ragdolls because it looks like ass
	local class = ent:GetClass()
	
	-- We do ghosting serverside in single player
	-- It's done clientside in multiplayer
	if (SERVER && !SinglePlayer()) then return end
	if (CLIENT && SinglePlayer()) then return end
	
	MakeGhostEntity( tab, ent:GetModel(), ent:GetPos(), ent:GetAngles() )
	
end

--[[---------------------------------------------------------
   Releases up the ghost entity
-----------------------------------------------------------]]
function ReleaseGhostEntity( tab )
	
	if ( tab.GhostEntity ) then
		if (!tab.GhostEntity:IsValid()) then tab.GhostEntity = nil return end
		tab.GhostEntity:Remove()
		tab.GhostEntity = nil
	end
	
	if ( tab.GhostEntities ) then
	
		for k,v in pairs( tab.GhostEntities ) do
			if ( v:IsValid() ) then v:Remove() end
			tab.GhostEntities[k] = nil
		end
		
		tab.GhostEntities = nil
	end
	
	if ( tab.GhostOffset ) then
	
		for k,v in pairs( tab.GhostOffset ) do
			tab.GhostOffset[k] = nil
		end
		
	end
	
end

--[[---------------------------------------------------------
   Update the ghost entity
-----------------------------------------------------------]]
function UpdateGhostEntity( tab )

	if (tab.GhostEntity == nil) then return end
	if (!tab.GhostEntity:IsValid()) then tab.GhostEntity = nil return end
	
	local tr = util.GetPlayerTrace( tab:GetOwner(), tab:GetOwner():GetCursorAimVector() )
	local trace = util.TraceLine( tr )
	if (!trace.Hit) then return end
	
	local Ang1, Ang2 = tab:GetNormal(1):Angle(), (trace.HitNormal * -1):Angle()
	local TargetAngle = tab:GetEnt(1):AlignAngles( Ang1, Ang2 )
	
	tab.GhostEntity:SetPos( tab:GetEnt(1):GetPos() )
	tab.GhostEntity:SetAngles( TargetAngle )
	
	local TranslatedPos = tab.GhostEntity:LocalToWorld( tab:GetLocalPos(1) )
	local TargetPos = trace.HitPos + (tab:GetEnt(1):GetPos() - TranslatedPos) + (trace.HitNormal)
	
	tab.GhostEntity:SetPos( TargetPos )
	
end
