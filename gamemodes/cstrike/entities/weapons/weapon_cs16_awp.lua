if CLIENT then
	SWEP.PrintName			= "Magnum Sniper Rifle"
	SWEP.Author				= "Schwarz Kruppzo"
end

if CLIENT then
	SWEP.WepSelectIcon = surface.GetTextureID("cs/sprites/awp_selecticon")
	SWEP.DrawWeaponInfoBox = false
	SWEP.BounceWeaponIcon = false
	killicons_new.Add("weapon_cs16_awp", "cs/sprites/awp_killicon", Color(255, 255, 255, 255))
end

SWEP.Slot				= 0
SWEP.SlotPos			= 1

SWEP.Base 				= "weapon_cs_base"
SWEP.Weight				= CS16_AWP_WEIGHT
SWEP.HoldType			= "ar2"

SWEP.Category			= "Counter-Strike"
SWEP.Spawnable			= true

--SWEP.PModel				= Model("models/weapons/cs16/p_awp.mdl")
SWEP.PModel				= Model("models/cs/p_awp.mdl")
SWEP.WModel				= Model("models/cs16/w_awp.mdl")
SWEP.VModel				= Model("models/weapons/cs16/c_awp.mdl")
--SWEP.VModel				= Model("models/cs/v_awp.mdl")

SWEP.ViewModel			= SWEP.VModel
SWEP.WorldModel			= SWEP.PModel

SWEP.Primary.Sound			= Sound("OldAWP.Shot1")
SWEP.Primary.EmptySound		= Sound("OldRifle.DryFire")
SWEP.Primary.ClipSize		= CS16_AWP_MAX_CLIP
SWEP.Primary.DefaultClip	= CS16_AWP_MAX_CLIP
SWEP.Primary.Ammo			= "CS16_338MAGNUM"
SWEP.Primary.Automatic		= true

SWEP.AnimPrefix 			= "rifle"
SWEP.MaxSpeed 				= CS16_AWP_MAX_SPEED
SWEP.Price 					= 4750

if !gmod.GetGamemode().IsCStrike then
	SWEP.Slot			= 2
	SWEP.SlotPos		= 0
	SWEP.PModel			= Model("models/weapons/cs16/player/p_awp.mdl")
end

function SWEP:OnSetupDataTables()
	self:NetworkVar("Float", 6, "EjectBrass")
	self:NetworkVar("Int", 1, "ScopeZoom")
	self:NetworkVar("Int", 2, "LastScopeZoom")
	self:NetworkVar("Bool", 5, "ResumeZoom")
end

function SWEP:OnDeploy()
	self:SendWeaponAnim(ACT_VM_DRAW)

	self:SetNextPrimaryFire(CurTime() + 1.45)
	self:SetNextSecondaryFire(CurTime() + 1)
end

function SWEP:PrimaryAttack()
	if !self.Owner:IsOnGround() then
		self:AWPFire(0.85, 1.45)
	elseif self.Owner:GetVelocity():Length2D() > 170 then
		self:AWPFire(0.25, 1.45)
	elseif self.Owner:GetVelocity():Length2D() > 10 then
		self:AWPFire(0.1, 1.45)
	elseif self.Owner:Crouching() then
		self:AWPFire(0, 1.45)
	else
		self:AWPFire(0.001, 1.45)
	end
end

function SWEP:SecondaryAttack()
	if CurTime() < self:GetNextSecondaryFire() or CurTime() < self:GetNextPrimaryFire() then 
		return
	end

	if self:GetScopeZoom() == 0 then
		self:SetScopeZoom(1)
	elseif self:GetScopeZoom() == 1 then
		self:SetScopeZoom(2)
	else
		self:SetScopeZoom(0)
	end

	self:EmitSound("weapons/zoom.wav")

	self:SetNextSecondaryFire(CurTime() + 0.3)
end

function SWEP:FireAnimation()
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
end

function SWEP:AWPFire(flSpread, flCycleTime)
	if self:Clip1() <= 0 then
		self:EmitSound(self.Primary.EmptySound)
		self:SetNextPrimaryFire(CurTime() + 0.2)

		return
	end

	if self:GetScopeZoom() != 0 then
		self:SetResumeZoom(true)
		self:SetLastScopeZoom(self:GetScopeZoom())
		self:SetScopeZoom(0)
	else
		flSpread = flSpread + 0.08
	end

	self:FireAnimation()
	self:TakePrimaryAmmo(1)

	self:CS16_MuzzleFlash(31, 30)
	self.Owner:SetAnimation(PLAYER_ATTACK1)

	self.Owner:FireBullets3(self, self.Owner:GetShootPos(), self.Owner:EyeAngles() + self.Owner:CS16_GetViewPunch(), flSpread, CS16_AWP_DISTANCE, CS16_AWP_PENETRATION, "CS16_338MAGNUM", CS16_AWP_DAMAGE, CS16_AWP_RANGE_MODIFER, self.Owner, true, self.Owner:EntIndex())

	self:EmitSound(self.Primary.Sound, 140)

	self:SetEjectBrass(CurTime() + 0.55)

	self.Owner:CS16_SetViewPunch(self.Owner:CS16_GetViewPunch() + Angle(-2, 0, 0), true)

	self:SetNextPrimaryFire(CurTime() + flCycleTime)
	self:SetTimeWeaponIdle(CurTime() + 2)
end

function SWEP:WeaponIdle() end

function SWEP:IsSniperRifle()
	return true
end

function SWEP:Reload()
	if self:GetInReload() then
		return 
	end

	if CLIENT and !IsFirstTimePredicted() then 
		return 
	end

	if self:CS16_DefaultReload(CS16_AWP_MAX_CLIP, ACT_VM_RELOAD, CS16_AWP_RELOAD_TIME) then
		self:SetResumeZoom(false)
		self:SetLastScopeZoom(0)
		self:SetScopeZoom(0)
	end
end

function SWEP:GetMaxSpeed()
	return self:GetScopeZoom() == 0 and CS16_AWP_MAX_SPEED or CS16_AWP_MAX_SPEED_ZOOM
end

function SWEP:AdjustMouseSensitivity()
	local var = {[0] = 1, [1] = 0.444, [2] = 0.133}
	return var[self:GetScopeZoom()] or 1
end

function SWEP:OnHolster()
	self:SetScopeZoom(0)
	self:SetLastScopeZoom(0)
end

function SWEP:OnThink()
	if self:GetNextPrimaryFire() <= CurTime() and self:GetResumeZoom() then
		self:SetScopeZoom(self:GetLastScopeZoom())
		if self:GetScopeZoom() == self:GetLastScopeZoom() then
			self:SetResumeZoom(false)
		end
	end

	if self:GetEjectBrass() != 0 and CurTime() >= self:GetEjectBrass() and IsFirstTimePredicted() then
		self:CreateShell(1, "1")
		self:SetEjectBrass(0)
	end
end

if CLIENT then
	function SWEP:OnCalcView(ply, pos, ang, fov)
		if self:GetScopeZoom() == 1 then
			fov = 33.3
		elseif self:GetScopeZoom() == 2 then
			fov = 10
		end

		return fov
	end

	function SWEP:OnPreViewModelDraw()
		if self:GetScopeZoom() != 0 then
			render.SetBlend(0)
		end
	end
	
	function SWEP:GetShellDir(attach)
		local ShellVelocity, ShellOrigin = Vector(), Vector()
		local velocity = self.Owner:GetVelocity()
		local punchangle = self.Owner:CS16_GetViewPunch()
		local angles = self.Owner:EyeAngles()
		angles.x = punchangle.x + angles.x
		angles.y = punchangle.y + angles.y

		ShellVelocity, ShellOrigin = CS16_GetDefaultShellInfo(self.Owner, attach, velocity, ShellVelocity, ShellOrigin, angles, 16, -9, self.ViewModelFlip and 9 or -9, false)

		return ShellOrigin, ShellVelocity, angles.y
	end
end

function SWEP:ShouldDrawViewModel()
	return (self:GetScopeZoom() == 0)
end
