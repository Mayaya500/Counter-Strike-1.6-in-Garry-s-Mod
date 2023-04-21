AddCSLuaFile("shared.lua")
include("shared.lua")

ENT.BounceSounds = {
	Sound("weapons/grenade_hit1.wav"),
	Sound("weapons/grenade_hit2.wav"),
	Sound("weapons/grenade_hit3.wav")
}
ENT.ExplosionSounds = {
	Sound("weapons/flashbang-1.wav"),
	Sound("weapons/flashbang-2.wav")
}

local STOP_EPSILON = 0.1
local function PhysicsClipVelocity(in_, normal, out, overbounce)
	local backoff = in_:DotProduct(normal) * overbounce
	local change = 0

	for i = 1 , 3 do
		change = normal[i] * backoff
		out[i] = in_[i] - change
		if out[i] > -STOP_EPSILON and out[i] < STOP_EPSILON then
			out[i] = 0
		end
	end
end

local function IsStandable(pOther)
	return pOther:GetSolid() == SOLID_BSP or pOther:GetSolid() == SOLID_VPHYSICS or pOther:GetSolid() == SOLID_BBOX
end

function ENT:Initialize()
	self:SetMoveType(MOVETYPE_FLYGRAVITY)
	self:SetSolid(SOLID_BBOX)
	self:SetModel("models/cs16/w_flashbang.mdl")
	self:SetCollisionBounds(Vector(-0.1, -0.1, -0.1), Vector(0.1, 0.1, 0.1))

	util.SpriteTrail(self, 0, Color(15, 186, 255, 150), false, 25, 1, 8, 1 / (15 + 1) * 0.5, "trails/smoke")
end

function ENT:ShootTimed(pOwner, vecVelocity, flTime)
	local angles = self:GetAngles()
	self:SetVelocity(vecVelocity)
	self:SetOwner(pOwner)
	
	self.dmgtime = CurTime() + flTime
	self:NextThink(CurTime() + .1)

	if flTime < .1 then
		self:SetVelocity(Vector())
	end

	self:ResetSequence(math.random(1, 3))
	self:SetPlaybackRate(4)
	self:SetAngles(Angle(0, angles.y, angles.r)) 

	self:SetGravity(0.5)
	self:SetFriction(0.8)
	self:SetElasticity(0.4)

	self.dmg = 35
end

ENT.Exploded = false
ENT.Radius = 300

function ENT:Beam()
	--local data = EffectData()
	--data:SetOrigin(self:GetPos())
	--util.Effect("cball_explode", data)

	local width = 64
	local radius = self.Radius * 1.5

	effects.BeamRingPoint(self:GetPos(), 0.2, 12, radius, width, 0, Color(15, 186, 255, 32), {
		speed = 0,
		spread = 0,
		delay = 0,
		framerate = 2,
		material = "sprites/lgtning.vmt"
	})
	-- Shockring
	effects.BeamRingPoint(self:GetPos(), 0.5, 12, radius, width, 0, Color(15, 186, 255, 64), {
		speed = 0,
		spread = 0,
		delay = 0,
		framerate = 2,
		material = "sprites/lgtning.vmt"
	})
end

function ENT:Explode(m_pTrace)
	local vHitPos, vHitNormal = m_pTrace.HitPos, m_pTrace.HitNormal

	/*
	if m_pTrace.Fraction != 1 then
		local tr = util.TraceLine({
			start = self:GetPos(),
			endpos = vHitPos + (vHitNormal * (self.dmg - 24) * 0.6),
			filter = self
		})
		self:SetPos(tr.HitPos)
	end
	*/

	local pos = self:GetPos()
	local data = EffectData()
	data:SetOrigin(pos)
	data:SetEntity(self)
	util.Effect("cs16_explosion_smoke2", data)
	util.Decal("Scorch", vHitPos + vHitNormal, vHitPos - vHitNormal)

	for k,v in pairs(ents.FindInSphere(pos, 300)) do
		if v:IsPlayer() and v:IsZombie() then
			v:Freeze(SUBGAMEMODE.CONFIG.FREEZE_GRENADE_DURATION)
		end
	end

	self.DeleteAfter = CurTime() + 4
	self.Exploded = true
	self:Beam()

	--CS16_RadiusFlash(pos, self, self:GetOwner(), 4, DMG_PLASMA)

	--self:EmitSound(self.ExplosionSounds[math.random(1, 2)], 400, 100, 1, CHAN_ITEM)
	self:EmitSound(GetCS16Sound("GRENADE_FROST_EXPLODE"), 400, 100, 1, CHAN_ITEM)
	
	--SafeRemoveEntity(self)
end

function ENT:Think()
	if !self:IsInWorld() then
		self:Remove()
		return
	end
	
	self:NextThink(CurTime() + .1)

	if self.Exploded then
		if self.DeleteAfter < CurTime() then
			SafeRemoveEntity(self)
		end
		return
	end

	if self.dmgtime <= CurTime() then
		local vecSpot = self:GetPos() + Vector(0 , 0 , 8)
		local tr = util.TraceLine({
			start = vecSpot,
			endpos = vecSpot + Vector(0, 0, -40),
			filter = self
		})

		self:Explode(tr)
	end

	if self:WaterLevel() != 0 then
		self:SetLocalVelocity(self:GetVelocity() * 0.5)
		self:SetPlaybackRate(0.2)
	end

	return true
end

function ENT:OnRemove() end

function ENT:StartTouch(ent2)
	if ent2:IsPlayer() and ent2:IsZombie() then
		local vecSpot = self:GetPos() + Vector(0 , 0 , 8)
		local tr = util.TraceLine({
			start = vecSpot,
			endpos = vecSpot + Vector(0, 0, -40),
			filter = self
		})
		self:Explode(tr)
	end
	self:ResolveFlyCollisionCustom(self:GetTouchTrace() , self:GetVelocity())
end

function ENT:Touch(m_hEntity)
	if !m_hEntity:IsSolid() or m_hEntity:GetSolidFlags() == FSOLID_VOLUME_CONTENTS then
		return
	end

	if m_hEntity == self:GetOwner() then
		return
	end

	local tr = util.TraceLine({
		start = self:GetPos(),
		endpos = self:GetPos() - Vector(0,0,10),
		mask = MASK_SOLID_BRUSHONLY,
		filter = self
	})

	if tr.Fraction < 1.0 then
		self:SetSequence(0)
		//self:SetAngles(Angle())
	end
	if self.Exploded then return end
	self:DoBounce()
end

function ENT:ResolveFlyCollisionCustom(trace , vecVelocity)
	local breakthrough = false

	if IsValid(trace.Entity) then
		if trace.Entity:GetClass() == "func_breakable" or trace.Entity:GetClass() == "func_breakable_surf" or (trace.Entity:GetClass() == "prop_physics" and trace.Entity:Health() != 0) then
			breakthrough = true
		end
	end

	if breakthrough then
		local info = DamageInfo()
		info:SetAttacker(self)
		info:SetInflictor(self)
		info:SetDamageForce(vecVelocity)
		info:SetDamagePosition(self:GetPos())
		info:SetDamageType(DMG_CLUB)
		info:SetDamage(10)
		trace.Entity:DispatchTraceAttack(info , trace , vecVelocity)
		
		if trace.Entity:Health() <= 0 then
			self:SetVelocity(vecVelocity)
			return
		end
	end
	
	local flTotalElasticity = self:GetFriction() / 2
	local vecAbsVelocity = Vector()
	PhysicsClipVelocity(self:GetVelocity(), trace.Normal, vecAbsVelocity, 2)
	vecAbsVelocity = vecAbsVelocity * flTotalElasticity
	vecVelocity = vecAbsVelocity + self:GetVelocity()

	local flSpeedSqr = vecVelocity:DotProduct(vecVelocity)
	if trace.Normal.z > 0.7 then
		local pEntity = trace.Entity

		self:SetVelocity(vecAbsVelocity)
		if flSpeedSqr < 600 then
			if IsStandable(pEntity) then
				self:SetGroundEntity(pEntity)
			end

			self:SetVelocity(Vector())
			self:SetLocalAngularVelocity(Angle())

			local angle = trace.Normal:Angle()
			angle.p = math.Rand(0, 360)
			self:SetAngles(angle)
		end
	else
		if flSpeedSqr < 600 then
			self:SetVelocity(Vector())
			self:SetLocalAngularVelocity(Angle())
		else
			self:SetVelocity(vecAbsVelocity)
		end
	end
end

ENT.NextBounceSound = 0
function ENT:DoBounce()
	if self.Exploded then return end
	if self.NextBounceSound < CurTime() then
		self:EmitSound(self.BounceSounds[math.random(1, 3)])
		self.NextBounceSound = CurTime() + 0.25
	end
end