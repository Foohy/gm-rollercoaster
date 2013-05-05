
--
-- prop_generic is the base for all other properties. 
-- All the business should be done in :Setup using inline functions.
-- So when you derive from this class - you should ideally only override Setup.
--

local PANEL = {}

function PANEL:Init()


end


function PANEL:Setup( vars )

	self:Clear()

	local ctrl = self:Add("DComboBox")
	ctrl:Dock( FILL )

	-- Add the choices provided in the enums given
	if istable(vars.enums) && #vars.enums > 0 then
		for k, v in pairs( vars.enums ) do
			ctrl:AddChoice(v)
		end
	end

	-- Return true if we're editing
	self.IsEditing = function( self )
		return ctrl.Menu != nil || ctrl.IsDepressed
	end

	-- Set the value
	self.SetValue = function( self, val )
		ctrl:ChooseOptionID( val ) 
	end

	-- Alert row that value changed
	ctrl.OnSelect = function(pnl, value, data)
		self:ValueChanged( value, true )
	end

end

derma.DefineControl( "DProperty_Enum", "", PANEL, "DProperty_Generic" )