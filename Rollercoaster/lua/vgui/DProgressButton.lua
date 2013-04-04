PANEL = {}

PANEL.Offset = 45 //Default value
PANEL.Height = 15
PANEL.ConVar = nil

PANEL.Button = nil
PANEL.Progress = nil

function PANEL:Init()

	self.Button = vgui.Create("DButton", self )
	self.Button:SetSize( self:GetSize() )
	self.Button.DoClick = function()
		if self.DoClick then
			pcall( self.DoClick )
		end
	end

	self.Progress = vgui.Create("DProgress", self )
	self.Progress:SetSize( self:GetSize() )

	self:SetShowProgress( false )
end

function PANEL:SetColor( color )
	self.Button:SetColor( color )
end

function PANEL:SetText( text )
	self.Button:SetText( text )
end

function PANEL:SetShowProgress( bool )
	self.Progress:SetVisible( bool )
	self.Progress:SetEnabled( bool )

	self.Button:SetVisible( !bool )
	self.Button:SetEnabled( !bool )
end

function PANEL:SetFraction( fraction )
	self.Progress:SetFraction( fraction )
end

function PANEL:OnMousePressed()

end

function PANEL:PerformLayout()
	DPanel.PerformLayout( self )
	self.Button:SetSize( self:GetSize() )
	self.Progress:SetSize( self:GetSize() )
end

derma.DefineControl( "DProgressButton", "A button that also shows progress", PANEL, "DPanel" )
