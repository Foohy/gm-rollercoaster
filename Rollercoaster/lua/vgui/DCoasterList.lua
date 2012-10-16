local PANEL = {}

AccessorFunc( PANEL, "m_bBackground",             "DrawBackground",         FORCE_BOOL )
AccessorFunc( PANEL, "m_bDirty",                 "Dirty",                 FORCE_BOOL )
AccessorFunc( PANEL, "m_bSortable",             "Sortable",             FORCE_BOOL )

AccessorFunc( PANEL, "m_iHeaderHeight",         "HeaderHeight" )
AccessorFunc( PANEL, "m_iDataHeight",             "DataHeight" )

AccessorFunc( PANEL, "m_bMultiSelect",             "MultiSelect" )

Derma_Hook( PANEL, "Paint", "Paint", "ListView" )


/*---------------------------------------------------------
   Name: Init
---------------------------------------------------------*/
function PANEL:Init()

    self:SetSortable( true )
    self:SetMouseInputEnabled( true )
    self:SetMultiSelect( true )

    self:SetDrawBackground( true )
    self:SetHeaderHeight( 16 )
    self:SetDataHeight( 17 )
    
    self.Columns = {}
    
    self.Lines = {}
    self.Sorted = {}
    
    self:SetDirty( true )
    
    self.pnlCanvas     = vgui.Create( "Panel", self )
    
    self.VBar         = vgui.Create( "DVScrollBar", self )
    self.VBar:SetZPos( 20 )

    self:AddColumn("Owner")
    self:AddColumn("ID")
    local build = self:AddColumn("Build Track")
    build:SetWidth(30)

end
/*
local function findpattern(text, pattern, start )
	return string.gsub( text, string.find(text, pattern, start))
end

local function GetIDNum( id )
	local pattern = findpattern( id, "_%d", 2 )
	return pattern
end
*/
function PANEL:UpdateTrackList()
	self:Clear()

	local found = {}
	local exists = false
	local coasterid = "dicks"

	for k, v in pairs( ents.FindByClass("coaster_node") ) do
		exists = false
		coasterid = v:GetCoasterID()

		for m, t in pairs( found ) do
			if coasterid == m then 
				exists = true
				continue
			end
		end

		if !exists then
			found[coasterid] = v
		end
	end

	for k, v in pairs( found ) do
		btn = vgui.Create("DButton", self )
		btn:SetText( "Build" )
		btn:CenterHorizontal()
		btn:SetWidth( 30 )
		btn:SetHeight( 10 )
		btn.DoClick = function()
			if !IsValid( v ) || !IsValid( v:GetController() ) then return end
			
			v:GetController():UpdateClientMesh()
		end

		self:AddLine( v:GetOwner():Name(), k,btn )
	end
end

/*---------------------------------------------------------
   Name: DisableScrollbar
---------------------------------------------------------*/
function PANEL:DisableScrollbar()

    if ( IsValid( self.VBar ) ) then
        self.VBar:Remove()
    end
    
    self.VBar = nil

end

/*---------------------------------------------------------
   Name: GetLines
---------------------------------------------------------*/
function PANEL:GetLines()
    return self.Lines
end



/*---------------------------------------------------------
   Name: GetInnerTall
---------------------------------------------------------*/
function PANEL:GetInnerTall()
    return self:GetCanvas():GetTall()
end

/*---------------------------------------------------------
   Name: GetCanvas
---------------------------------------------------------*/
function PANEL:GetCanvas()
    return self.pnlCanvas
end

/*---------------------------------------------------------
   Name: AddColumn
---------------------------------------------------------*/
function PANEL:AddColumn( strName, strMaterial, iPosition )

    local pColumn = nil
    
    if ( self.m_bSortable ) then
        pColumn = vgui.Create( "DListView_Column", self )
    else
        pColumn = vgui.Create( "DListView_ColumnPlain", self )
    end
        pColumn:SetName( strName )
        pColumn:SetMaterial( strMaterial )
        pColumn:SetZPos( 10 )

        
    if ( iPosition ) then
    
        // Todo, insert in specific position
        
    else
    
        local ID = table.insert( self.Columns, pColumn )
        pColumn:SetColumnID( ID )
    
    end

    self:InvalidateLayout()
    
    return pColumn
    
end

/*---------------------------------------------------------
   Name: RemoveLine
---------------------------------------------------------*/
function PANEL:RemoveLine( LineID )

    local Line = self:GetLine( LineID )
    local SelectedID = self:GetSortedID( LineID )
    
    self.Lines[ LineID ] = nil
    table.remove( self.Sorted, SelectedID )

    self:SetDirty( true )
    self:InvalidateLayout()
    
    Line:Remove()

end

/*---------------------------------------------------------
   Name: ColumnWidth
---------------------------------------------------------*/
function PANEL:ColumnWidth( i )

    local ctrl = self.Columns[ i ]
    if (!ctrl) then return 0 end
    
    return ctrl:GetWide()

end

/*---------------------------------------------------------
   Name: FixColumnsLayout
---------------------------------------------------------*/
function PANEL:FixColumnsLayout()

    local NumColumns = #self.Columns
    if ( NumColumns == 0 ) then return end

    local AllWidth = 0
    for k, Column in pairs( self.Columns ) do
        AllWidth = AllWidth + Column:GetWide()
    end
    
    local ChangeRequired = self.pnlCanvas:GetWide() - AllWidth
    local ChangePerColumn = math.floor( ChangeRequired / NumColumns )
    local Remainder = ChangeRequired - (ChangePerColumn * NumColumns)
    
    for k, Column in pairs( self.Columns ) do

        local TargetWidth = Column:GetWide() + ChangePerColumn
        Remainder = Remainder + ( TargetWidth - Column:SetWidth( TargetWidth ) )
    
    end
    
    // If there's a remainder, try to palm it off on the other panels, equally
    while ( Remainder != 0 ) do

        local PerPanel = math.floor( Remainder / NumColumns )
        
        for k, Column in pairs( self.Columns ) do
    
            Remainder = math.Approach( Remainder, 0, PerPanel )
            
            local TargetWidth = Column:GetWide() + PerPanel
            Remainder = Remainder + (TargetWidth - Column:SetWidth( TargetWidth ))
            
            if ( Remainder == 0 ) then break end
        
        end
        
        Remainder = math.Approach( Remainder, 0, 1 )
    
    end
        
    // Set the positions of the resized columns
    local x = 0
    for k, Column in pairs( self.Columns ) do
    
        Column.x = x
        x = x + Column:GetWide()
        
        Column:SetTall( self:GetHeaderHeight() )
    
    end

end

/*---------------------------------------------------------
   Name: Paint
---------------------------------------------------------*/
function PANEL:PerformLayout()
    
    // Do Scrollbar
    local Wide = self:GetWide()
    local YPos = 0
    
    if ( IsValid( self.VBar ) ) then
    
        self.VBar:SetPos( self:GetWide() - 16, 0 )
        self.VBar:SetSize( 16, self:GetTall() )
        self.VBar:SetUp( self.VBar:GetTall() - self:GetHeaderHeight(), self.pnlCanvas:GetTall() )
        YPos = self.VBar:GetOffset()

        if ( self.VBar.Enabled ) then Wide = Wide - 16 end
    
    end
    
    self.pnlCanvas:SetPos( 0, YPos + self:GetHeaderHeight() )
    self.pnlCanvas:SetSize( Wide, self.pnlCanvas:GetTall() )
    
    self:FixColumnsLayout()
    
    //
    // If the data is dirty, re-layout
    //
    if ( self:GetDirty( true ) ) then
    
        self:SetDirty( false )
        local y = self:DataLayout()
        self.pnlCanvas:SetTall( y )
        
        // Layout again, since stuff has changed..
        self:InvalidateLayout( true )
    
    end
    


end



/*---------------------------------------------------------
   Name: OnScrollbarAppear
---------------------------------------------------------*/
function PANEL:OnScrollbarAppear()

    self:SetDirty( true )
    self:InvalidateLayout()

end

/*---------------------------------------------------------
   Name: OnRequestResize
---------------------------------------------------------*/
function PANEL:OnRequestResize( SizingColumn, iSize )
    
    // Find the column to the right of this one
    local Passed = false
    local RightColumn = nil
    for k, Column in ipairs( self.Columns ) do
    
        if ( Passed ) then
            RightColumn = Column
            break
        end
    
        if ( SizingColumn == Column ) then Passed = true end
    
    end
    
    // Alter the size of the column on the right too, slightly
    if ( RightColumn ) then
    
        local SizeChange = SizingColumn:GetWide() - iSize
        RightColumn:SetWide( RightColumn:GetWide() + SizeChange )
        
    end
    
    SizingColumn:SetWide( iSize )
    self:SetDirty( true )
    
    // Invalidating will munge all the columns about and make it right
    self:InvalidateLayout()

end

/*---------------------------------------------------------
   Name: DataLayout
---------------------------------------------------------*/
function PANEL:DataLayout()

    local y = 0
    local h = self.m_iDataHeight
    
    for k, Line in ipairs( self.Sorted ) do
    
        Line:SetPos( 0, y )
        Line:SetSize( self:GetWide(), h )
        Line:DataLayout( self )
        
        Line:SetAltLine( k % 2 == 1 )
        
        y = y + Line:GetTall()
    
    end
    
    return y

end

/*---------------------------------------------------------
   Name: AddLine - returns the line number.
---------------------------------------------------------*/
function PANEL:AddLine( ... )

    self:SetDirty( true )
    self:InvalidateLayout()

    local Line = vgui.Create( "DListView_Line", self.pnlCanvas )
    local ID = table.insert( self.Lines, Line )
    
    Line:SetListView( self )
    Line:SetID( ID )
    
    // This assurs that there will be an entry for every column
    for k, v in pairs( self.Columns ) do
        Line:SetColumnText( k, "" )
    end

    for k, v in pairs( {...} ) do
        Line:SetColumnText( k, v )
    end
    
    // Make appear at the bottom of the sorted list
    local SortID = table.insert( self.Sorted, Line )
    
    if ( SortID % 2 == 1 ) then
        Line:SetAltLine( true )
    end

    return Line
    
end

/*---------------------------------------------------------
   Name: OnMouseWheeled
---------------------------------------------------------*/
function PANEL:OnMouseWheeled( dlta )

    if ( !IsValid( self.VBar ) ) then return end
    
    return self.VBar:OnMouseWheeled( dlta )
    
end

/*---------------------------------------------------------
   Name: OnMouseWheeled
---------------------------------------------------------*/
function PANEL:ClearSelection( dlta )

    for k, Line in pairs( self.Lines ) do
        Line:SetSelected( false )
    end
    
end

/*---------------------------------------------------------
   Name: GetSelectedLine
---------------------------------------------------------*/
function PANEL:GetSelectedLine()

    for k, Line in pairs( self.Lines ) do
        if ( Line:GetSelected() ) then return k end
    end
    
end

/*---------------------------------------------------------
   Name: GetLine
---------------------------------------------------------*/
function PANEL:GetLine( id )

    return self.Lines[ id ]
    
end

/*---------------------------------------------------------
   Name: GetSortedID
---------------------------------------------------------*/
function PANEL:GetSortedID( line )

    for k, v in pairs( self.Sorted ) do
    
        if ( v:GetID() == line ) then return k end
    
    end
    
end

/*---------------------------------------------------------
   Name: OnClickLine
---------------------------------------------------------*/
function PANEL:OnClickLine( Line, bClear )
    
end

function PANEL:SortByColumns( c1, d1, c2, d2, c3, d3, c4, d4 )

    table.Copy( self.Sorted, self.Lines )
    
    table.sort( self.Sorted, function( a, b )
                                
                                if (!IsValid( a )) then return true end
                                if (!IsValid( b )) then return false end
                                
                                if ( c1 && a:GetColumnText( c1 ) != b:GetColumnText( c1 ) ) then
                                    if ( d1 ) then a, b = b, a end
                                    return a:GetColumnText( c1 ) < b:GetColumnText( c1 )
                                end
                                
                                if ( c2 && a:GetColumnText( c2 ) != b:GetColumnText( c2 ) ) then
                                    if ( d2 ) then a, b = b, a end
                                    return a:GetColumnText( c2 ) < b:GetColumnText( c2 )
                                end
                                    
                                if ( c3 && a:GetColumnText( c3 ) != b:GetColumnText( c3 ) ) then
                                    if ( d3 ) then a, b = b, a end
                                    return a:GetColumnText( c3 ) < b:GetColumnText( c3 )
                                end
                                
                                if ( c4 && a:GetColumnText( c4 ) != b:GetColumnText( c4 ) ) then
                                    if ( d4 ) then a, b = b, a end
                                    return a:GetColumnText( c4 ) < b:GetColumnText( c4 )
                                end
                                
                                return true                            
                        end )

    self:SetDirty( true )
    self:InvalidateLayout()

end

/*---------------------------------------------------------
   Name: SortByColumn
---------------------------------------------------------*/
function PANEL:SortByColumn( ColumnID, Desc )

    table.Copy( self.Sorted, self.Lines )
    
    table.sort( self.Sorted, function( a, b )

                                    if ( Desc ) then
                                        a, b = b, a
                                    end
            
                                    return a:GetColumnText( ColumnID ) < b:GetColumnText( ColumnID )
                            
                        end )

    self:SetDirty( true )
    self:InvalidateLayout()
    

end

/*---------------------------------------------------------
   Name: SelectFirstItem
   Selects the first item based on sort..
---------------------------------------------------------*/
function PANEL:SelectItem( Item )

    if ( !Item ) then return end
    
    Item:SetSelected( true )
    self:OnRowSelected( Item:GetID(), Item )

end

/*---------------------------------------------------------
   Name: SelectFirstItem
   Selects the first item based on sort..
---------------------------------------------------------*/
function PANEL:SelectFirstItem()

    self:ClearSelection()
    self:SelectItem( self.Sorted[ 1 ] )

end

/*---------------------------------------------------------
   Name: DoDoubleClick
---------------------------------------------------------*/
function PANEL:DoDoubleClick( LineID, Line )

    // For Override

end

/*---------------------------------------------------------
   Name: OnRowSelected
---------------------------------------------------------*/
function PANEL:OnRowSelected( LineID, Line )

    // For Override

end

/*---------------------------------------------------------
   Name: OnRowRightClick
---------------------------------------------------------*/
function PANEL:OnRowRightClick( LineID, Line )

    // For Override

end

/*---------------------------------------------------------
   Name: Clear
---------------------------------------------------------*/
function PANEL:Clear()

    for k, v in pairs( self.Lines ) do
        v:Remove()
    end
    
    self.Lines = {}
    self.Sorted = {}
    
    self:SetDirty( true )

end

/*---------------------------------------------------------
   Name: GetSelected
---------------------------------------------------------*/
function PANEL:GetSelected()

    local ret = {}
    
    for k, v in pairs( self.Lines ) do
        if ( v:IsSelected() ) then
            table.insert( ret, v )
        end
    end

    return ret

end


/*---------------------------------------------------------
   Name: SizeToContents
---------------------------------------------------------*/
function PANEL:SizeToContents( )

    self:SetHeight( self.pnlCanvas:GetTall() + self:GetHeaderHeight() )
    

end


/*---------------------------------------------------------
   Name: GenerateExample
---------------------------------------------------------*/
function PANEL:GenerateExample( ClassName, PropertySheet, Width, Height )

    local ctrl = vgui.Create( ClassName )
        
        local Col1 = ctrl:AddColumn( "Address" )
        local Col2 = ctrl:AddColumn( "Port" )
    
        Col2:SetMinWidth( 30 )
        Col2:SetMaxWidth( 30 )
    
        for i=1, 128 do
            ctrl:AddLine( "192.168.0."..i, "80" )
        end
        
        ctrl:SetSize( 300, 200 )
        
    PropertySheet:AddSheet( ClassName, ctrl, nil, true, true )

end


derma.DefineControl( "DCoasterList", "Coaster List View", PANEL, "Panel" )