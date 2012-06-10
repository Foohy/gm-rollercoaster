/************
	Bezier curve controller by foohy with references from
	the planetfall catmull rom spline script.
	holy fuck how am i going to do this
***********/
AddCSLuaFile("autorun/sh_bezier_controller.lua")

local Controller = {}
Controller.STEPS = 20

function Controller:New(host_ent)
	local obj = {}
	
	obj.__index = Controller
	setmetatable(obj, obj)
	
	obj.PointsList = {}
	obj.ControlList = {}
	
	obj.FacingsList   = {}
	obj.RotationsList = {}
	
	obj.Spline   = {}
	obj.ZoomList = {}
	
	obj.EntityList = {host_ent}
	
	obj.DurationList = {}
	
	obj.Host = host_ent
	
	obj.CLEntityListCount = 0
	
	return obj
end

function Controller:Reset()
	self.PointsList = {}

	self.ControlList = {}
end

function Controller:AddPoint(index, vec, duration)
	self.PointsList[index]   = vec
	self.DurationList[index] = duration or 2
end

function Controller:AddAngle(index, ang, duration)
	self.FacingsList[index]   = ang:Forward()
	self.RotationsList[index] = ang.r
	
	self.DurationList[index] = duration or 2
end

function Controller:AddPointAngle(index, vec, ctrl1, ctrl2)
	self.PointsList[index] = vec
	self.ControlList[index] = {}
	self.ControlList[index].Control1 = ctrl1 or ( vec - Vector(100, 0, 0) )
	self.ControlList[index].Control2 = ctrl2 or ( vec + Vector( 100, 0, 0 ) )
end

function Controller:CalcPerc()
	-- Isolate a very specific issue where if it was at segment 3 and
	-- you removed/undid to 4 nodes it would panic.
	
	if (i == 3) and (#self.PointsList == 4) then
		self.CurSegment = 2
	end
	
	if self.CurSegmentTimestamp == 0 then
		self.CurSegmentTimestamp = CurTime() + self.DurationList[self.CurSegment]
	end
	
	if not self.DurationList[self.CurSegment] then
		if SERVER then
			return self.Host:End()
		end
		
		return 
	end
	
	self.Perc = 1 - ((self.CurSegmentTimestamp - CurTime()) / (self.DurationList[self.CurSegment] + .001)) -- So you can't put in zero easily
	
	if self.Perc > 1 then
		self:EndSegment()
	end
	
	return self.Perc
end

function Controller:EndSegment()
	self.Perc = self.Perc - 1
	
	self.CurSegment = self.CurSegment + 1
	
	if self.Host.OnChangeSegment then
		self.Host:OnChangeSegment(self.CurSegment)
	end
	
	if self.CurSegment > (#self.PointsList - 2) then -- I know this looks repetitive
		self.CurSegment = 2
		
		if SERVER then
			self.Host:End()
		end
	end
	
	self.CurSegmentTimestamp = CurTime() + self.DurationList[self.CurSegment]
	
	return self.Perc
end

/****
	explanataion for this
	a = Vector of the first point (starting destination)
	b = Vector of the 2nd node (Control point of the first point)
	c = Vector of the 3rd node (Control point of the last point)
	d = Vector of the 4th node (Ending position)
	t = Time, or better described as percent along the track from 0 to 1
****/
function Bezier( a, b, c, d, t )
	local ab,bc,cd,abbc,bccd 
	
	ab = LerpVector(t, a, b)
	bc = LerpVector(t, b, c)
	cd = LerpVector(t, c, d)
	abbc = LerpVector(t, ab, bc)
	bccd = LerpVector(t, bc, cd)
	dest = LerpVector(t, abbc, bccd)
	
	return dest //HOLY SHIT BEZIERSS
end

//WHATTHEFUCK
function Controller:BezierCalc(i, perc)
	perc = perc or self.Perc
	
	if i == -1 then
		return ((-perc + 2) * perc - 1) * perc * .5
	elseif i == 0 then
		return (((3 * perc - 5) * perc) * perc + 2) * .5
	elseif i == 1 then
		return ((-3 * perc + 4) * perc + 1)*perc * .5
	elseif i == 2 then
		return ((perc - 1) * perc * perc) * .5
	else
		ErrorNoHalt("Invalid i: ", i, "\n")
	end
	
	return 0
end

function Controller:Point(i, perc)
	perc = perc or self.Perc
	i = i or self.CurSegment
	
	local vec = Vector(0, 0, 0)
	
	local safeguard = (#self.PointsList - 1)
	
	-- Isolate a very specific issue where if it was at segment 3 and
	-- you removed/undid to 4 nodes it would panic.
	
	if i > safeguard then
		i = safeguard
		
		self.CurSegment = i
	end
	
	if self.PointsList[i] && self.ControlList[i] then
		local pt0 = self.PointsList[i]
		local pt1 = self.ControlList[i].Control2
		local pt2 = self.ControlList[i+1].Control1
		local pt3 = self.PointsList[i+1]

		vec = Bezier(pt0, pt1, pt2, pt3, perc)
	end	
/*
	for j = -1, 2 do
		local idx  = i + j
		local multi = self:BezierCalc(j, perc)
		
		if self.PointsList[idx] then
			vec.x = vec.x + (multi * self.PointsList[idx].x)
			vec.y = vec.y + (multi * self.PointsList[idx].y)
			vec.z = vec.z + (multi * self.PointsList[idx].z)
		end
	end
	*/
    return vec
end

function Controller:Angle(i, perc) -- Gods rotted euler angles! Let's use a pseudo quaternion-like rotation scheme instead. :3
	perc = perc or self.Perc
	i = i or self.CurSegment
	
	-- My intellect is superior to this!
	--[[
	do -- It would have been VERY nice of someone to tell me that LerpAngle was a C++ function which used Quaternions. :downs:
		return LerpAngle(perc, self.AnglesList[i], self.AnglesList[i + 1])
		--return QuaternionNLerp(self.AnglesList[i]:Quaternion(), self.AnglesList[i + 1]:Quaternion(), perc):ToAngle()
	end
	--]]
	
	local facing   = Vector(0, 0, 0)
	local rotation = 0
	
	local safeguard = (#self.PointsList - 1)
	
	-- Isolate a very specific issue where if it was at segment 3 and
	-- you removed/undid to 4 nodes it would panic.
	
	if i > safeguard then
		i = safeguard
		
		self.CurSegment = i
	end
	
	for j = -1, 2 do
		local idx  = i + j
		local multi = self:CatmullRomCalc(j, perc)
		
		if self.FacingsList[idx] then
			facing.x = facing.x + (multi * self.FacingsList[idx].x)
			facing.y = facing.y + (multi * self.FacingsList[idx].y)
			facing.z = facing.z + (multi * self.FacingsList[idx].z)
			
			rotation = rotation + (multi * self.RotationsList[idx])
		end
	end
	
	local ang = facing:Angle()
	ang.r     = rotation
	--print(ang)
    return ang
end

function Controller:CalcEntireSpline()
	local nodecount = #self.PointsList
	
	if nodecount < 2 then
		return ErrorNoHalt("Not enough nodes given, I need two and was given ", nodecount, ".\n")
	end
	
	local pointcount = 0
	
	for index = 1, (nodecount - 1) do
		for j = 1, Controller.STEPS do
			pointcount = pointcount + 1	
			self.Spline[pointcount] = self:Point(index, j / Controller.STEPS)
		end
	end
end

function Controller:GetCurrentSpline(i, perc)	
	local spline = (i - 2) * self.STEPS + (self.STEPS * perc)
	//print(math.floor(spline))
	return math.Clamp( math.floor(spline), 1, #self.Spline)
end


CoasterManager.BezierController = Controller
