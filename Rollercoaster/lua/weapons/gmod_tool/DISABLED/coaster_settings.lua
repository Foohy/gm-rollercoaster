TOOL.Category   = "Rollercoaster"
TOOL.Name       = "Track Settings"
TOOL.Command    = nil
TOOL.ConfigName	= nil

TOOL.ClientConVar["r"] = "255"
TOOL.ClientConVar["g"] = "255"
TOOL.ClientConVar["b"] = "255"

TOOL.ClientConVar["tracktype"] = "1"

function TOOL:LeftClick(trace)
	local ply   = self:GetOwner()
	
	trace = {}
	trace.start  = ply:GetShootPos()
	trace.endpos = trace.start + (ply:GetAimVector() * 99999999)
	trace.filter = ply
	trace = util.TraceLine(trace)

	local CartNum = GetClientNumber( self, "cart_amount")
	local Powered = GetClientNumber( self, "powered")
	local tracktype = GetClientNumber( self, "tracktype")
	local r = tonumber(GetClientNumber( self, "r")) or 255
	local g = tonumber(GetClientNumber( self, "g")) or 255
	local b = tonumber(GetClientNumber( self, "b")) or 255
	
	local Ent = trace.Entity
	
	if IsValid( Ent ) && Ent:GetClass() == "coaster_node" then
		if SERVER then 
			local controller = Ent:GetController()

			if IsValid( controller ) then
				print("Editing settings for "..tostring(controller.CoasterID))
				controller:SetTrackColor(r,g,b)
				controller:SetTrackType(tracktype)
			end
		end
	
		return true
	end

end

function TOOL:RightClick(trace)
	local ply   = self:GetOwner()
	
	trace = {}
	trace.start  = ply:GetShootPos()
	trace.endpos = trace.start + (ply:GetAimVector() * 99999999)
	trace.filter = ply
	trace = util.TraceLine(trace)

	local CartNum = GetClientNumber( self, "cart_amount")
	local Powered = GetClientNumber( self, "powered")
	
	local Ent 		= trace.Entity
	
	if IsValid( Ent ) && Ent:GetClass() == "coaster_node" then
		if SERVER then
			local controller = Ent:GetController()
		
			if IsValid( controller ) && SERVER then 
				print("Doing nothing for "..tostring(controller.CoasterID))
				//controller:ClearTrains()
			end
		end
		
		return true
	end
end

function TOOL:Reload(trace)

end

function TOOL:Think()
	if CLIENT then
		local ply = LocalPlayer()

		trace = {}
		trace.start  = ply:GetShootPos()
		trace.endpos = trace.start + (ply:GetAimVector() * 999999)
		trace.filter = ply
		trace = util.TraceLine(trace)

		if IsValid( trace.Entity ) && ( trace.Entity:GetClass() == "coaster_node") then
			local controller = trace.Entity:GetController()
			if IsValid( controller ) then
				SelectAllNodes( controller, Color( 180 - math.random( 0, 80 ), 220 - math.random( 0, 50 ), 255, 255 ) )
			end
		else 
			ClearNodeSelection()
		end

	end
end

function TOOL:ValidTrace(trace)

end

function TOOL:Holster()
	if CLIENT then
		ClearNodeSelection()
	end
end

function TOOL.BuildCPanel(panel)	
	panel:AddControl("Color", { Label = "Track Color", Multiplier = 255, ShowAlpha = false, Red = "coaster_settings_r", Green = "coaster_settings_g", Blue = "coaster_settings_b"})
	local ComboBox = vgui.Create("DComboBox", panel)

	//Create some nice choices
	if EnumNames.Tracks && #EnumNames.Tracks > 0 then
		for k, v in pairs( EnumNames.Tracks ) do
			ComboBox:AddChoice(v)
		end
		local trackConVar = GetConVar("coaster_settings_tracktype" )

		if trackConVar && trackConVar:GetInt() > 0 then
			ComboBox:ChooseOptionID( trackConVar:GetInt() )
			RunConsoleCommand("coaster_settings_tracktype", trackConVar:GetInt() ) //Default to normal
		else
			ComboBox:ChooseOptionID( COASTER_TRACK_METAL )
			RunConsoleCommand("coaster_settings_tracktype", COASTER_TRACK_METAL ) //Default to normal
		end
	end

	ComboBox.OnSelect = function(index, value, data)
		RunConsoleCommand("coaster_settings_tracktype" , tostring( value ) )
	end

	ComboBox:ChooseOptionID( 1 )
	panel:AddItem( ComboBox )

	panel:AddControl( "Header", { Text = "#Tool_coaster_settings_name", Description = "#Tool_coaster_settings_desc" }  )
end

if CLIENT then

	language.Add( "Tool_coaster_settings_name", "Track Settings" )
	language.Add( "Tool_coaster_settings_desc", "Change track-wide settings" )
	language.Add( "Tool_coaster_settings_0", "Click on any node of a rollercoaster to update its settings" )

end

