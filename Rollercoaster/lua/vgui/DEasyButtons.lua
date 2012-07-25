PANEL = {}

PANEL.Offset = 45 //Default value
PANEL.Height = 15
PANEL.ConVar = nil

//Derma_Hook( PANEL, "Paint", "Paint", "ExpandButton" )

BTN_ZERO 		= 1
BTN_ADD 		= 2
BTN_SUBTRACT 	= 3

function PANEL:Init()

	//Create three buttons
	self.BtnReset = vgui.Create("DButton", self )
	self.BtnReset:SetText( "Reset" )
	self.BtnReset:CenterHorizontal()
	self.BtnReset:SetWidth( 60 )
	self.BtnReset:SetHeight( self.Height )

	self.BtnPositive = vgui.Create("DButton", self)
	self.BtnPositive:SetText( "+ " .. self.Offset)
	self.BtnPositive:MoveRightOf( self.BtnReset )
	self.BtnPositive:SetHeight( self.Height )

	self.BtnNegative = vgui.Create("DButton", self)
	self.BtnNegative:SetText( "- " .. self.Offset)
	self.BtnNegative:MoveLeftOf( self.BtnReset )
	self.BtnNegative:SetHeight( self.Height )

	//hook into their click functions
	self.BtnReset.DoClick = function() self:ButtonPress( BTN_ZERO ) end
	self.BtnPositive.DoClick = function() self:ButtonPress( BTN_ADD ) end
	self.BtnNegative.DoClick = function() self:ButtonPress( BTN_SUBTRACT ) end

end

function PANEL:ButtonPress( enum )
	if !self.ConVar then return end

	if enum == BTN_ZERO then
		RunConsoleCommand( self.ConVar, 0)
	elseif enum == BTN_ADD then
		local value = GetConVarNumber( self.ConVar )
		RunConsoleCommand( self.ConVar, value + self.Offset )
	elseif enum == BTN_SUBTRACT then
		local value = GetConVarNumber( self.ConVar )
		RunConsoleCommand( self.ConVar, value - self.Offset )
	end
end

function PANEL:PerformLayout()
	DPanel.PerformLayout( self )
	self.BtnReset:CenterHorizontal()
	self.BtnReset:SetWidth( 50 )
	
	self.BtnPositive:SetText( "+ " .. self.Offset)
	self.BtnNegative:SetText( "- " .. self.Offset)


	self.BtnPositive:MoveRightOf( self.BtnReset )
	self.BtnNegative:MoveLeftOf( self.BtnReset )

end

derma.DefineControl( "DEasyButtons", "", PANEL, "Panel" )
