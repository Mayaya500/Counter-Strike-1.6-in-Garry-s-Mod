if CLIENT then
	SWEP.PrintName			= "Smoke Grenade"
	SWEP.Author				= "Schwarz Kruppzo"
end

if CLIENT then
	SWEP.WepSelectIcon = surface.GetTextureID("cs/sprites/smokegrenade_selecticon")
	SWEP.DrawWeaponInfoBox = false
	SWEP.BounceWeaponIcon = false
end

SWEP.Slot				= 3
SWEP.SlotPos			= 2

SWEP.Base 				= "weapon_cs_base"
SWEP.Weight				= CS16_SMOKEGRENADE_WEIGHT
SWEP.HoldType			= "grenade"

SWEP.Category			= "Counter-Strike"
SWEP.Spawnable			= true

--SWEP.PModel				= Model("models/weapons/cs16/p_smokegrenade.mdl")
SWEP.PModel				= Model("models/cs/p_smokegrenade.mdl")
SWEP.WModel				= Model("models/cs16/w_smokegrenade.mdl")
SWEP.VModel				= Model("models/weapons/cs16/c_smokegrenade.mdl")
--SWEP.VModel				= Model("models/cs/v_smokegrenade.mdl")

SWEP.PModelShield		= Model("models/weapons/cs16/shield/p_shield_smokegrenade.mdl")
SWEP.VModelShield		= Model("models/weapons/cs16/shield/v_shield_smokegrenade.mdl")

SWEP.ViewModel			= SWEP.VModel
SWEP.WorldModel			= SWEP.PModel

SWEP.Primary.ClipSize		= -1
--SWEP.Primary.DefaultClip	= CS16_SMOKEGRENADE_MAX_CARRY
SWEP.Primary.DefaultClip	= 0
SWEP.Primary.Ammo			= "CS16_SMOKEGRENADE"

SWEP.AnimPrefix 			= "grenade"
SWEP.MaxSpeed 				= CS16_SMOKEGRENADE_MAX_SPEED
SWEP.Price 					= 300
SWEP.IsGrenade 				= true

if !gmod.GetGamemode().IsCStrike then
	SWEP.Slot			= 4
	SWEP.SlotPos		= 2
	SWEP.PModel			= Model("models/weapons/cs16/player/p_smokegrenade.mdl")
end

function SWEP:OnSetupDataTables()
	self:NetworkVar("Float", 6, "ThrowTime")
	self:NetworkVar("Bool", 5, "PinPulled")
	self:NetworkVar("Bool", 6, "Redraw")
end

function SWEP:OnDeploy()
	if self.Owner:HasShield() then
		self.ViewModel = self.VModelShield
		self.Owner:GetViewModel():SetWeaponModel(self.ViewModel, self)
	else
		self.ViewModel = self.VModel
		self.Owner:GetViewModel():SetWeaponModel(self.ViewModel, self)
	end

	local vm = self.Owner:GetViewModel()
	vm:SendViewModelMatchingSequence(vm:SelectWeightedSequence(ACT_VM_DRAW))

	self:SetRedraw(false)
	self:SetPinPulled(false)
	self:SetThrowTime(0)
end

function SWEP:OnHolster()
	self:SetRedraw(false)
	self:SetPinPulled(false)
	self:SetThrowTime(0)
end

function SWEP:PrimaryAttack()
	if self.Owner:IsShieldDrawn() then return end
	if self:GetRedraw() or self:GetPinPulled() or self:GetThrowTime() > 0 then return end
	if self.Owner:GetAmmoCount(self.Primary.Ammo) <= 0 then return end

	local vm = self.Owner:GetViewModel()
	vm:SendViewModelMatchingSequence(vm:SelectWeightedSequence(ACT_VM_PULLPIN))

	self:SetPinPulled(true)

	self:SetNextPrimaryFire(CurTime() + 0.5)
	self:SetTimeWeaponIdle(CurTime() + 0.5)
end

function SWEP:SecondaryAttack()
	if CurTime() < self:GetNextSecondaryFire() then 
		return
	end

	if self:ShieldSecondaryAttack() then
		return
	end
end

function SWEP:Reload()
	return
end

function SWEP:Throw()
	local angleThrow = self.Owner:EyeAngles() + self.Owner:CS16_GetViewPunch(CLIENT)

	if angleThrow.p < 0 then
		angleThrow.p = -10 + angleThrow.p * ((90 - 10) / 90)
	else
		angleThrow.p = -10 + angleThrow.p * ((90 + 10) / 90)
	end

	local vel = (90 - angleThrow.p) * 6

	if vel > 750 then
		vel = 750
	end
	
	local forward = angleThrow:Forward()
	local vecSrc = self.Owner:GetShootPos() + forward * 16
	local vecThrow = forward * vel + self.Owner:GetVelocity()

	if SERVER then
		local grenade = ents.Create("ent_cs16_smokegrenade")
		grenade:SetAngles(vecThrow:Angle())
		grenade:SetPos(vecSrc)
		grenade:Spawn()
		grenade:ShootTimed(self.Owner, vecThrow, 1.5)

		--if self.Owner.Radio then
		--	self.Owner:Radio("ct_fireinhole.wav", "csl_Fire_in_the_Hole")
		--end
	end

	local vm = self.Owner:GetViewModel()
	vm:SendViewModelMatchingSequence(vm:SelectWeightedSequence(ACT_VM_THROW))
	self.Owner:SetAnimation(PLAYER_ATTACK1)

	self:TakePrimaryAmmo(1)

	self:SetRedraw(true)
	self:SetThrowTime(0)
	self:SetNextPrimaryFire(CurTime() + 0.5)
	self:SetTimeWeaponIdle(CurTime() + 0.75)

	if self.Owner:GetAmmoCount(self.Primary.Ammo) == 0 then
		self:SetNextAttack(CurTime() + 0.5)
		self:SetTimeWeaponIdle(CurTime() + 0.5)
	end
end

function SWEP:OnThink()
	if self:GetPinPulled() and !self.Owner:KeyDown(IN_ATTACK) and CurTime() > self:GetTimeWeaponIdle() then
		local vm = self.Owner:GetViewModel()

		self:SetThrowTime(CurTime() + 0.1)
		self:SetPinPulled(false)
		vm:SendViewModelMatchingSequence(vm:SelectWeightedSequence(ACT_VM_THROW))

		self:SetNextPrimaryFire(CurTime() + 0.5)
		self:SetTimeWeaponIdle(CurTime() + 0.5)
	elseif self:GetThrowTime() > 0 and self:GetThrowTime() < CurTime() then
		self:Throw()
	end
end

function SWEP:WeaponIdle()
	if self:GetTimeWeaponIdle() > CurTime() then
		return
	end

	local vm = self.Owner:GetViewModel()

	if self.Owner.HasShield and self.Owner:HasShield() and self.Owner:IsShieldDrawn() then
		self:SetTimeWeaponIdle(CurTime() + 20)

		vm:SendViewModelMatchingSequence(vm:SelectWeightedSequence(ACT_SHIELD_UP_IDLE))
	elseif self:GetRedraw() then
		self:SetRedraw(false)

		if self.Owner:GetAmmoCount(self.Primary.Ammo) > 0 then
			vm:SendViewModelMatchingSequence(vm:SelectWeightedSequence(ACT_VM_DRAW))

			self:SetTimeWeaponIdle(CurTime() + math.Rand(10, 15))
		else
			if SERVER then 
				if self.Owner.CS16_SelectBestWeapon then
					self.Owner:CS16_SelectBestWeapon(self)
				else
					self.Owner:ConCommand("lastinv")
				end

				SafeRemoveEntity(self)
			end
		end
	elseif self.Owner:GetAmmoCount(self.Primary.Ammo) != 0 and !self:GetPinPulled() then
		self:SetTimeWeaponIdle(CurTime() + math.Rand(10, 15))
	end
end

function SWEP:CanDrop()
	return false
end