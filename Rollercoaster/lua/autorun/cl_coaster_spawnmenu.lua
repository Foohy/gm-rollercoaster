

hook.Add( "AddToolMenuTabs", "Coaster_add_tab", function()
	spawnmenu.AddToolTab("Rollercoaster", "Rollercoaster")

end )

hook.Add( "AddToolMenuCategories", "Coaster_add_category", function()
	spawnmenu.AddToolCategory( "Rollercoaster", "Perfomance", "Perfomance" )
end )

hook.Add("PopulateToolMenu", "Coaster_add_menus", function() 
	spawnmenu.AddToolMenuOption( "Rollercoaster", "Perfomance", "coaster_tweaks", "Tweaks", "", "", CoasterTweaksMenu )

end )

function CoasterTweaksMenu( Panel )
	Panel:ClearControls()

	Panel:AddControl("Slider",   {Label = "Max Wheels per Segment", Description = "Maximum wheels to render per segment", Type = "Int", Min = "0", Max = "100", Command = "coaster_maxwheels"})
	Panel:AddControl("CheckBox", {Label = "Track Previews: ", Description = "Draw track previews", Command = "coaster_previews"})
	Panel:AddControl("CheckBox", {Label = "Track Supports: ", Description = "Draw track support beams", Command = "coaster_supports"})
	Panel:AddControl("CheckBox", {Label = "Motion Blur: ", Description = "Draw fancy motion blur", Command = "coaster_motionblur"})

end


MAIN TOOL FILE

TOOL:LeftClick()
	self.CurrentTab.LeftClick()
end

SOME OTHER TOOL FILE

TAB:LeftClick()
	//lol do shit
end