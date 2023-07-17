-- Module
local AutoParry = {
	EntityData = {},
	OtherConnections = {},
	SoundConnections = {},
	Connections = {},
	IsAutoParryRunning = false,
	TimeWhenOutOfRange = nil,
	IsPlayerSwinging = false,
	AnimationFeint = false,
	StartedBlocking = false,
	SoundFeint = false,
}

-- Services
local Players = GetService("Players")
local WorkspaceService = GetService("Workspace")
local StatsService = GetService("Stats")

-- Requires
local Helper = require("Modules/Helpers/Helper")
local Pascal = require("Modules/Helpers/Pascal")
local AutoParryLogger = require("Features/AutoParryLogger")

function AutoParry.CheckDistanceBetweenParts(BuilderData, Part1, Part2)
	if not BuilderData or not BuilderData.MaximumDistance or not BuilderData.MinimumDistance then
		return false
	end

	-- Nullify out the height in our calculations
	local Part1Position = Vector3.new(Part1.Position.X, 0.0, Part1.Position.Z)
	local Part2Position = Vector3.new(Part2.Position.X, 0.0, Part2.Position.Z)

	-- Get distance
	local Distance = (Part1Position - Part2Position).Magnitude

	local DistanceAdjust = (Pascal:GetConfig().AutoParry.AdjustDistancesBySlider or 0)
	local MinimumDistance = Pascal:GetMethods().Max(BuilderData.MinimumDistance, 0)
	local MaximumDistance = Pascal:GetMethods().Max(BuilderData.MaximumDistance + DistanceAdjust, 0)
	return Distance >= MinimumDistance and Distance <= MaximumDistance
end

function AutoParry.HasTalent(Entity, TalentString)
	if not TalentString:match("Talent:") then
		TalentString = "Talent:" .. TalentString
	end

	local PlayerFromCharacter = Players:GetPlayerFromCharacter(Entity)
	if
		PlayerFromCharacter
		and PlayerFromCharacter.Backpack
		and PlayerFromCharacter.Backpack:FindFirstChild(TalentString)
	then
		return true
	end

	if Entity:FindFirstChild(TalentString) then
		return true
	end

	return false
end

function AutoParry.RunFeintFn(LocalPlayerData)
	if Pascal:GetConfig().AutoParry.InputMethod == "KeyPress" then
		-- Send mouse event
		Pascal:GetMethods().Mouse2Press()

		-- Data by mouse press tool which will time mouse presses
		local MousePressDelay = Pascal:GetMethods().Random(0.026, 0.095)

		-- Delay script before sending another
		Pascal:GetMethods().Wait(MousePressDelay)

		-- Send mouse event to unpress key
		Pascal:GetMethods().Mouse2Release()
	end
end

function AutoParry.RunDodgeFn(Entity, ShouldRollCancel, RollCancelDelay, ShouldGoBack)
	if Pascal:GetConfig().AutoParry.InputMethod == "KeyPress" then
		-- Run event to roll...
		Pascal:GetMethods().KeyPress(0x51)

		-- Check if we should go back...
		if ShouldGoBack then
			-- Key press (InputClient -> On F press)
			Pascal:GetMethods().KeyPress(0x53)

			-- Key release (InputClient -> On F Release)
			Pascal:GetMethods().KeyRelease(0x53)
		end

		-- Check if we should roll cancel...
		if ShouldRollCancel then
			-- Calculate delay...
			local AttemptMilisecondsConvertedToSeconds = RollCancelDelay / 1000 or 0

			-- Delay script before sending another
			Pascal:GetMethods().Wait(AttemptMilisecondsConvertedToSeconds)

			-- Send mouse event to cancel roll...
			Pascal:GetMethods().Mouse2Press()

			-- Data by mouse press tool which will time mouse presses
			local MousePressDelay = Pascal:GetMethods().Random(0.026, 0.095)

			-- Delay script before sending another
			Pascal:GetMethods().Wait(MousePressDelay)

			-- Send mouse event to unpress key
			Pascal:GetMethods().Mouse2Release()
		end

		return
	end
end

function AutoParry.StartBlockFn()
	if Pascal:GetConfig().AutoParry.InputMethod == "KeyPress" then
		-- Send key event
		Pascal:GetMethods().KeyPress(0x46)
		return
	end
end

function AutoParry.EndBlockFn()
	if Pascal:GetConfig().AutoParry.InputMethod == "KeyPress" then
		-- Send key event to unpress key
		Pascal:GetMethods().KeyRelease(0x46)
		return
	end
end

function AutoParry.BlockUntilBlockState()
	local EffectReplicator = Pascal:GetEffectReplicator()

	-- Block until actually blocking
	while Pascal:GetMethods().Wait() do
		-- Make sure we can actually get the LocalPlayer's data
		local LocalPlayerData = Helper.GetLocalPlayerWithData()
		if not LocalPlayerData then
			break
		end

		-- Check for the CharacterHandler & InputClient & Requests
		local CharacterHandler = LocalPlayerData.Character:FindFirstChild("CharacterHandler")
		if not CharacterHandler or not CharacterHandler:FindFirstChild("InputClient") then
			break
		end

		local LeftHand = LocalPlayerData.Character:FindFirstChild("LeftHand")
		local RightHand = LocalPlayerData.Character:FindFirstChild("RightHand")
		if not LeftHand or not RightHand then
			break
		end

		local HandWeapon = LeftHand:FindFirstChild("HandWeapon") or RightHand:FindFirstChild("HandWeapon")
		if not HandWeapon then
			break
		end

		if not Pascal:GetConfig().AutoParry.Enabled then
			break
		end

		if not EffectReplicator:FindEffect("Action") and not EffectReplicator:FindEffect("Knocked") then
			Pascal:GetMethods().KeyPress(0x46)
		end

		if EffectReplicator:FindEffect("Blocking") then
			break
		end
	end
end

function AutoParry.RunParryFn()
	if Pascal:GetConfig().AutoParry.InputMethod == "KeyPress" then
		-- Key press (InputClient -> On F Pressed)
		Pascal:GetMethods().KeyPress(0x46)

		-- Key hold until block state (InputClient -> On F Pressed)
		AutoParry.BlockUntilBlockState()

		-- Key release (InputClient -> On F Release)
		Pascal:GetMethods().KeyRelease(0x46)
		return
	end
end

function AutoParry.Notify(Text, Time)
	if not Pascal:GetConfig().AutoParry.ShowAutoParryNotifications then
		return
	end

	Library:Notify(Text, Time)
end

function AutoParry.MovementCheck(EffectReplicator)
	if EffectReplicator:FindEffect("Action") then
		return false
	end

	if EffectReplicator:FindEffect("NoParkour") then
		return false
	end

	if EffectReplicator:FindEffect("Knocked") then
		return false
	end

	if EffectReplicator:FindEffect("Unconscious") then
		return false
	end

	if not EffectReplicator:FindEffect("Pinned") then
		if not EffectReplicator:FindEffect("Carried") then
			return true
		end
	end

	return false
end

function AutoParry.CheckFacingThresholdOnPlayers(LocalPlayerData, HumanoidRootPart)
	local DeltaOnTargetToLocal = (LocalPlayerData.HumanoidRootPart.Position - HumanoidRootPart.Position).Unit
	local TargetToLocalResult = LocalPlayerData.HumanoidRootPart.CFrame.LookVector:Dot(DeltaOnTargetToLocal) <= -0.1
	local DeltaOnLocalToTarget = (HumanoidRootPart.Position - LocalPlayerData.HumanoidRootPart.Position).Unit
	local LocalToTargetResult = HumanoidRootPart.CFrame.LookVector:Dot(DeltaOnLocalToTarget) <= -0.1

	-- Check if enemy looking at you...
	if Pascal:GetConfig().AutoParry.EnemyLookingAtYou and not Pascal:GetConfig().AutoParry.IfLookingAtEnemy then
		return TargetToLocalResult
	end

	-- Check if looking at enemy...
	if Pascal:GetConfig().AutoParry.IfLookingAtEnemy and not Pascal:GetConfig().AutoParry.EnemyLookingAtYou then
		return LocalToTargetResult
	end

	-- Check if enemy looking at you and you looking at enemy...
	if Pascal:GetConfig().AutoParry.EnemyLookingAtYou and Pascal:GetConfig().AutoParry.IfLookingAtEnemy then
		return TargetToLocalResult and LocalToTargetResult
	end

	-- Return true otherwise...
	return true
end

function AutoParry.ValidateState(
	AnimationTrack,
	BuilderData,
	LocalPlayerData,
	HumanoidRootPart,
	Humanoid,
	Player,
	SkipCheckForAttacking,
	AfterDelay,
	FirstTime,
	SpecialType
)
	-- Only do this if there is a valid humanoid-root-part...
	if HumanoidRootPart and LocalPlayerData.HumanoidRootPart then
		-- Check animation distance
		if
			not AutoParry.CheckDistanceBetweenParts(BuilderData, HumanoidRootPart, LocalPlayerData.HumanoidRootPart)
			and Player ~= LocalPlayerData.Player
			and not BuilderData.DelayUntilInRange
		then
			return false
		end

		-- Part1, Part2
		local Part1 = HumanoidRootPart
		local Part2 = LocalPlayerData.HumanoidRootPart

		-- Nullify out the height in our calculations
		local Part1Position = Vector3.new(Part1.Position.X, 0.0, Part1.Position.Z)
		local Part2Position = Vector3.new(Part2.Position.X, 0.0, Part2.Position.Z)

		-- Get distance
		local Distance = (Part1Position - Part2Position).Magnitude

		-- Check if we have DelayUntilInRange enabled...
		-- Make sure the distance from isn't too far away aswell...
		if
			Player ~= LocalPlayerData.Player
			and BuilderData.DelayUntilInRange
			and not AutoParry.CheckDistanceBetweenParts(BuilderData, HumanoidRootPart, LocalPlayerData.HumanoidRootPart)
			and Distance <= Pascal:GetConfig().AutoParry.DistanceThresholdInRange
		then
			-- Notify user that we have triggered delay until in range
			AutoParry.Notify("Player went out of range, delaying until in range...", 2.0)

			-- Save time to account for delay later...
			AutoParry.TimeWhenOutOfRange = Pascal:GetMethods().ExecutionClock()

			repeat
				Pascal:GetMethods().Wait()
			until AutoParry.CheckDistanceBetweenParts(BuilderData, HumanoidRootPart, LocalPlayerData.HumanoidRootPart)

			-- Resume...
			AutoParry.Notify("Back in range, resuming auto-parry...", 2.0)
		end

		-- Check if players are facing each-other
		if
			not AutoParry.CheckFacingThresholdOnPlayers(LocalPlayerData, HumanoidRootPart)
			and Player ~= LocalPlayerData.Player
		then
			return false
		end
	end

	if not Humanoid or Humanoid.Health <= 0 then
		return false
	end

	-- Effect handling...
	local EffectReplicator = Pascal:GetEffectReplicator()

	-- If we're currently attacking we are unable to parry!
	local InsideOfAttack = EffectReplicator:FindEffect("LightAttack")
		and not EffectReplicator:FindEffect("OffhandAttack")

	if
		not SkipCheckForAttacking
		and not Pascal:GetConfig().AutoParry.AutoFeint
		and InsideOfAttack
		and AutoParry.IsPlayerSwinging
		and Player ~= LocalPlayerData.Player
	then
		return false
	end

	if
		Pascal:GetConfig().AutoParry.AutoFeint
		and InsideOfAttack
		and AutoParry.IsPlayerSwinging
		and Player ~= LocalPlayerData.Player
	then
		-- Notify user that we have triggered auto-feint
		AutoParry.Notify(
			string.format(
				"Triggered auto-feint on %s(%s)",
				BuilderData.NickName,
				BuilderData.AnimationId and BuilderData.AnimationId
					or BuilderData.PartName and BuilderData.PartName
					or BuilderData.SoundId
			),
			2.0
		)

		-- Run feint function...
		AutoParry.RunFeintFn()

		-- Reset IsPlayerSwinging...
		AutoParry.IsPlayerSwinging = false
	end

	-- Cannot parry while we are casting a spell...
	if AfterDelay and EffectReplicator:FindEffect("CastingSpell") and Player ~= LocalPlayerData.Player then
		return false
	end

	-- Can't parry or do anything while we are crouching...
	if AfterDelay and EffectReplicator:FindEffect("Crouching") then
		return false
	end

	-- Can't roll if we are unable to
	if
		AfterDelay
		and BuilderData.ShouldRoll
		and not AutoParry.CanRoll(LocalPlayerData, HumanoidRootPart, EffectReplicator)
		and Player ~= LocalPlayerData.Player
	then
		-- Notify user...
		AutoParry.Notify(
			string.format(
				"Cannot dodge on animation %s(%s)",
				BuilderData.NickName,
				SpecialType == "Animation" and BuilderData.AnimationId
					or SpecialType == "Sound" and BuilderData.SoundId
					or BuilderData.PartName
			),
			2.0
		)

		return false
	end

	-- Cannot block while inside of an action or we are knocked
	if
		AfterDelay
		and (EffectReplicator:FindEffect("Action") or EffectReplicator:FindEffect("Knocked"))
		and Player ~= LocalPlayerData.Player
	then
		return false
	end

	-- Is our animaton still playing?
	if not SpecialType then
		if not BuilderData.ActivateOnEnd and not AnimationTrack.IsPlaying then
			return false
		end
	end

	-- Did they feint?
	if not BuilderData.ActivateOnEnd and (AutoParry.SoundFeint or AutoParry.AnimationFeint) then
		return false
	end

	-- Return true
	return true
end

-- This delay function makes sure that our current state is valid across delays
function AutoParry.DelayAndValidateStateFn(
	DelayInSeconds,
	AnimationTrack,
	BuilderData,
	LocalPlayerData,
	HumanoidRootPart,
	Humanoid,
	Player,
	SkipCheckForAttacking,
	SpecialType
)
	-- Make sure we are valid...
	if
		not AutoParry.ValidateState(
			AnimationTrack,
			BuilderData,
			LocalPlayerData,
			HumanoidRootPart,
			Humanoid,
			Player,
			SkipCheckForAttacking,
			false,
			false,
			SpecialType
		)
	then
		return false
	end

	-- Wait the delay out...
	Pascal:GetMethods().Wait(DelayInSeconds)

	-- Make sure we are still valid...
	if
		not AutoParry.ValidateState(
			AnimationTrack,
			BuilderData,
			LocalPlayerData,
			HumanoidRootPart,
			Humanoid,
			Player,
			SkipCheckForAttacking,
			true,
			false,
			SpecialType
		)
	then
		return false
	end

	return true
end

function AutoParry.CanRoll(LocalPlayerData, HumanoidRootPart, EffectReplicator)
	if EffectReplicator:FindEffect("CarryObject") then
		if not EffectReplicator:FindEffect("ClientSwim") then
			return false
		end
	end

	if EffectReplicator:FindEffect("UsingSpell") then
		return false
	end

	if not AutoParry.MovementCheck(EffectReplicator) then
		return false
	end

	if EffectReplicator:FindEffect("NoAttack") then
		if not EffectReplicator:FindEffect("CanRoll") then
			return false
		end
	end

	if EffectReplicator:FindEffect("Dodged") then
		return false
	end

	if EffectReplicator:FindEffect("NoRoll") then
		return false
	end

	if EffectReplicator:FindEffect("Stun") then
		return false
	end

	if EffectReplicator:FindEffect("Action") then
		return false
	end

	if EffectReplicator:FindEffect("Carried") then
		return false
	end

	if EffectReplicator:FindEffect("MobileAction") then
		return false
	end

	if EffectReplicator:FindEffect("PreventAction") then
		return false
	end

	local PressureForwardOrMisDirection = EffectReplicator:FindEffect("PressureForward")
		or AutoParry.HasTalent(LocalPlayerData.Character, "Talent:Misdirection")

	if EffectReplicator:FindEffect("LightAttack") then
		if not PressureForwardOrMisDirection then
			return false
		end
	end

	if EffectReplicator:FindEffect("ClientSlide") then
		return false
	end

	if HumanoidRootPart:FindFirstChild("GravBV") then
		return false
	end

	return true
end

function AutoParry:EmplaceAnimationToData(PlayerData, AnimationTrack, AnimationId)
	if not PlayerData.AnimationData[AnimationId] then
		local AnimationData = {
			AnimationTrack = AnimationTrack,
			StartedBlocking = false,
		}

		PlayerData.AnimationData[AnimationId] = AnimationData
	end

	return PlayerData.AnimationData[AnimationId]
end

function AutoParry:EmplaceEntityToData(Entity)
	if not AutoParry.EntityData[Entity] then
		local EntityData = {
			AnimationData = {},
			MarkedForDeletion = true,
		}

		AutoParry.EntityData[Entity] = EntityData
	end

	return AutoParry.EntityData[Entity]
end

function AutoParry:GetBuilderData(Type, Identifier)
	-- Builder settings list
	local BuilderSettingsList = Pascal:GetConfig().AutoParryBuilder[Type].BuilderSettingsList
	return BuilderSettingsList[Identifier]
end

function AutoParry:OnPartInRange(Entity, Part, Player, HumanoidRootPart, Humanoid)
	if not HumanoidRootPart then
		return
	end

	-- Ok, before we do anything... Let's check for these first.
	local LocalPlayerData = Helper.GetLocalPlayerWithData()
	if not LocalPlayerData or LocalPlayerData.Humanoid.Health <= 0 then
		return
	end

	local LeftHand = LocalPlayerData.Character:FindFirstChild("LeftHand")
	local RightHand = LocalPlayerData.Character:FindFirstChild("RightHand")
	if not LeftHand or not RightHand then
		return
	end

	local HandWeapon = LeftHand:FindFirstChild("HandWeapon") or RightHand:FindFirstChild("HandWeapon")
	if not HandWeapon then
		return
	end

	if not Pascal:GetConfig().AutoParry.Enabled then
		return
	end

	if LocalPlayerData.Player == Player and not Pascal:GetConfig().AutoParry.LocalAttackAutoParry then
		return
	end

	-- Get sound builder data
	local BuilderData = AutoParry:GetBuilderData("Part", Part.Name)
	if not BuilderData then
		return
	end

	-- Validate current auto-parry state is OK
	if
		not AutoParry.ValidateState(
			nil,
			BuilderData,
			LocalPlayerData,
			HumanoidRootPart,
			Humanoid,
			Player,
			false,
			false,
			true,
			"Part"
		)
	then
		return
	end

	if not Entity:FindFirstChild("Humanoid") and string.lower(BuilderData.PartParentName) == "humanoid" then
		return
	end

	if
		string.lower(BuilderData.PartParentName) ~= "none"
		and string.lower(BuilderData.PartParentName) ~= ""
		and not string.find(string.lower(Entity.Name), string.lower(BuilderData.PartParentName))
		and string.lower(BuilderData.PartParentName) ~= "humanoid"
	then
		return
	end

	-- Randomize seed according to the timestamp (ms)
	Pascal:GetMethods().RandomSeed(DateTime.now().UnixTimestampMillis)

	-- Check hitchance
	if Pascal:GetMethods().Random(0.0, 100.0) > Pascal:GetConfig().AutoParry.Hitchance then
		return
	end

	-- Calculate delay(s)
	local function CalculateCurrentDelay()
		local AttemptMilisecondsConvertedToSeconds = Pascal:GetMethods().ToNumber(BuilderData.AttemptDelay)
				and Pascal:GetMethods().ToNumber(BuilderData.AttemptDelay) / 1000
			or 0

		local RepeatMilisecondsConvertedToSeconds = Pascal:GetMethods().ToNumber(BuilderData.ParryRepeatDelay)
				and Pascal:GetMethods().ToNumber(BuilderData.ParryRepeatDelay) / 1000
			or 0

		-- Delay(s) accounting for global delay...
		AttemptMilisecondsConvertedToSeconds = AttemptMilisecondsConvertedToSeconds
			+ ((Pascal:GetConfig().AutoParry.AdjustTimingsBySlider / 1000) or 0)

		RepeatMilisecondsConvertedToSeconds = RepeatMilisecondsConvertedToSeconds
			+ ((Pascal:GetConfig().AutoParry.AdjustTimingsBySlider / 1000) or 0)

		-- Ping converted to two decimal places...
		local PingAdjustmentAmount = Pascal:GetMethods()
			.Max(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000, 0.0) * Pascal:GetMethods().Clamp(
			((Pascal:GetConfig().AutoParry.PingAdjust or 0) / 100),
			0.0,
			1.0
		)

		local RepeatDelayAccountingForPingAdjustment = Pascal:GetMethods()
			.Max(RepeatMilisecondsConvertedToSeconds - PingAdjustmentAmount, 0.0)

		local AttemptDelayAccountingForPingAdjustment =
			Pascal:GetMethods().Max(AttemptMilisecondsConvertedToSeconds - PingAdjustmentAmount, 0.0)

		return {
			AttemptDelay = AttemptDelayAccountingForPingAdjustment,
			RepeatDelay = RepeatDelayAccountingForPingAdjustment,
		}
	end

	-- Get delay
	local CurrentDelay = CalculateCurrentDelay()

	-- Notify
	AutoParry.Notify(
		string.format(
			"Delaying on part %s(%s) for %.3f seconds",
			BuilderData.NickName,
			BuilderData.PartName,
			CurrentDelay.AttemptDelay
		),
		2.0
	)

	-- Set that we are running
	AutoParry.IsAutoParryRunning = true

	-- Wait for delay to occur
	local DelayResult = AutoParry.DelayAndValidateStateFn(
		CurrentDelay.AttemptDelay,
		nil,
		BuilderData,
		LocalPlayerData,
		HumanoidRootPart,
		Humanoid,
		Player,
		false,
		"Part"
	)

	-- Set that we are not running
	AutoParry.IsAutoParryRunning = false

	if not DelayResult then
		-- Notify user that delay has failed
		AutoParry.Notify(
			string.format(
				"Failed delay on part %s(%s) due to state validation",
				BuilderData.NickName,
				BuilderData.PartName
			),
			2.0
		)

		return
	end

	-- Handle auto-parry repeats
	if
		BuilderData.ParryRepeat
		and not BuilderData.ShouldBlock
		and not BuilderData.ShouldRoll
		and not BuilderData.ParryRepeatAnimationEnds
	then
		local RepeatDelayResult = nil

		-- Loop how many times we need to repeat...
		for RepeatIndex = 0, (BuilderData.ParryRepeatTimes or 0) do
			-- Get delay
			local CurrentDelay = CalculateCurrentDelay()

			-- Parry
			AutoParry.RunParryFn()

			-- Notify user that animation has repeated
			AutoParry.Notify(
				string.format(
					"(%i) Activated on part %s(%s) (%s: %.3f seconds)",
					RepeatIndex,
					BuilderData.NickName,
					BuilderData.PartName,
					RepeatDelayResult and "repeat-delay" or "delay",
					RepeatDelayResult and CurrentDelay.RepeatDelay or CurrentDelay.AttemptDelay
				),
				2.0
			)

			-- Set that we are running
			AutoParry.IsAutoParryRunning = true

			-- Wait for delay to occur
			RepeatDelayResult = AutoParry.DelayAndValidateStateFn(
				CurrentDelay.RepeatDelay,
				nil,
				BuilderData,
				LocalPlayerData,
				HumanoidRootPart,
				Humanoid,
				Player,
				true,
				"Part"
			)

			-- Set that we are not running
			AutoParry.IsAutoParryRunning = false

			if not RepeatDelayResult then
				-- Notify user that delay has failed
				AutoParry.Notify(
					string.format(
						"Failed delay on part %s(%s) due to state validation",
						BuilderData.NickName,
						BuilderData.PartName
					),
					2.0
				)
			end
		end

		-- Return...
		return
	end

	-- Handle normal auto-parry
	if not BuilderData.ShouldBlock and not BuilderData.ShouldRoll and not BuilderData.ParryRepeat then
		-- Run auto-parry
		AutoParry.RunParryFn()

		-- Notify user that animation has ended
		AutoParry.Notify(string.format("Activated on part %s(%s)", BuilderData.NickName, BuilderData.PartName), 2.0)

		-- Return...
		return
	end

	-- Handle dodging
	if BuilderData.ShouldRoll then
		-- Start dodging...
		AutoParry.RunDodgeFn(
			Entity,
			Pascal:GetConfig().AutoParry.ShouldRollCancel,
			Pascal:GetConfig().AutoParry.RollCancelDelay
		)

		-- Notify user that we have dodged
		AutoParry.Notify(string.format("Dodged part %s(%s)", BuilderData.NickName, BuilderData.PartName), 2.0)

		-- Return...
		return
	end
end

function AutoParry:OnSoundPlayed(EntityData, Sound, Player, HumanoidRootPart, Humanoid)
	if not HumanoidRootPart then
		return
	end

	-- Ok, before we do anything... Let's check for these first.
	local LocalPlayerData = Helper.GetLocalPlayerWithData()
	if not LocalPlayerData or LocalPlayerData.Humanoid.Health <= 0 then
		return
	end

	local LeftHand = LocalPlayerData.Character:FindFirstChild("LeftHand")
	local RightHand = LocalPlayerData.Character:FindFirstChild("RightHand")
	if not LeftHand or not RightHand then
		return
	end

	local HandWeapon = LeftHand:FindFirstChild("HandWeapon") or RightHand:FindFirstChild("HandWeapon")
	if not HandWeapon then
		return
	end

	if not Pascal:GetConfig().AutoParry.Enabled then
		return
	end

	if LocalPlayerData.Player == Player and not Pascal:GetConfig().AutoParry.LocalAttackAutoParry then
		return
	end

	-- Get sound builder data
	local BuilderData = AutoParry:GetBuilderData("Sound", Sound.SoundId)
	if not BuilderData then
		return
	end

	-- Validate current auto-parry state is OK
	if
		not AutoParry.ValidateState(
			nil,
			BuilderData,
			LocalPlayerData,
			HumanoidRootPart,
			Humanoid,
			Player,
			false,
			false,
			true,
			"Sound"
		)
	then
		return
	end

	-- Randomize seed according to the timestamp (ms)
	Pascal:GetMethods().RandomSeed(DateTime.now().UnixTimestampMillis)

	-- Check hitchance
	if Pascal:GetMethods().Random(0.0, 100.0) > Pascal:GetConfig().AutoParry.Hitchance then
		return
	end

	-- Calculate delay(s)
	local function CalculateCurrentDelay()
		local AttemptMilisecondsConvertedToSeconds = Pascal:GetMethods().ToNumber(BuilderData.AttemptDelay)
				and Pascal:GetMethods().ToNumber(BuilderData.AttemptDelay) / 1000
			or 0

		local RepeatMilisecondsConvertedToSeconds = Pascal:GetMethods().ToNumber(BuilderData.ParryRepeatDelay)
				and Pascal:GetMethods().ToNumber(BuilderData.ParryRepeatDelay) / 1000
			or 0

		-- Delay(s) accounting for global delay...
		AttemptMilisecondsConvertedToSeconds = AttemptMilisecondsConvertedToSeconds
			+ ((Pascal:GetConfig().AutoParry.AdjustTimingsBySlider / 1000) or 0)

		RepeatMilisecondsConvertedToSeconds = RepeatMilisecondsConvertedToSeconds
			+ ((Pascal:GetConfig().AutoParry.AdjustTimingsBySlider / 1000) or 0)

		-- Ping converted to two decimal places...
		local PingAdjustmentAmount = Pascal:GetMethods()
			.Max(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000, 0.0) * Pascal:GetMethods().Clamp(
			((Pascal:GetConfig().AutoParry.PingAdjust or 0) / 100),
			0.0,
			1.0
		)

		local RepeatDelayAccountingForPingAdjustment = Pascal:GetMethods()
			.Max(RepeatMilisecondsConvertedToSeconds - PingAdjustmentAmount, 0.0)

		local AttemptDelayAccountingForPingAdjustment =
			Pascal:GetMethods().Max(AttemptMilisecondsConvertedToSeconds - PingAdjustmentAmount, 0.0)

		return {
			AttemptDelay = AttemptDelayAccountingForPingAdjustment,
			RepeatDelay = RepeatDelayAccountingForPingAdjustment,
		}
	end

	-- Get delay
	local CurrentDelay = CalculateCurrentDelay()

	-- Notify
	AutoParry.Notify(
		string.format(
			"Delaying on sound %s(%s) for %.3f seconds",
			BuilderData.NickName,
			BuilderData.SoundId,
			CurrentDelay.AttemptDelay
		),
		2.0
	)

	-- Set that we are running
	AutoParry.IsAutoParryRunning = true

	-- Wait for delay to occur
	local DelayResult = AutoParry.DelayAndValidateStateFn(
		CurrentDelay.AttemptDelay,
		nil,
		BuilderData,
		LocalPlayerData,
		HumanoidRootPart,
		Humanoid,
		Player,
		false,
		"Sound"
	)

	-- Set that we are not running
	AutoParry.IsAutoParryRunning = false

	if not DelayResult then
		-- Notify user that delay has failed
		AutoParry.Notify(
			string.format(
				"Failed delay on sound %s(%s) due to state validation",
				BuilderData.NickName,
				BuilderData.SoundId
			),
			2.0
		)

		return
	end

	-- Handle auto-parry repeats
	if
		BuilderData.ParryRepeat
		and not BuilderData.ShouldBlock
		and not BuilderData.ShouldRoll
		and not BuilderData.ParryRepeatAnimationEnds
	then
		local RepeatDelayResult = nil

		-- Loop how many times we need to repeat...
		for RepeatIndex = 0, (BuilderData.ParryRepeatTimes or 0) do
			-- Get delay
			local CurrentDelay = CalculateCurrentDelay()

			-- Parry
			AutoParry.RunParryFn()

			-- Notify user that animation has repeated
			AutoParry.Notify(
				string.format(
					"(%i) Activated on sound %s(%s) (%s: %.3f seconds)",
					RepeatIndex,
					BuilderData.NickName,
					BuilderData.SoundId,
					RepeatDelayResult and "repeat-delay" or "delay",
					RepeatDelayResult and CurrentDelay.RepeatDelay or CurrentDelay.AttemptDelay
				),
				2.0
			)

			-- Set that we are running
			AutoParry.IsAutoParryRunning = true

			-- Wait for delay to occur
			RepeatDelayResult = AutoParry.DelayAndValidateStateFn(
				CurrentDelay.RepeatDelay,
				nil,
				BuilderData,
				LocalPlayerData,
				HumanoidRootPart,
				Humanoid,
				Player,
				true,
				"Sound"
			)

			-- Set that we are not running
			AutoParry.IsAutoParryRunning = false

			if not RepeatDelayResult then
				-- Notify user that delay has failed
				AutoParry.Notify(
					string.format(
						"Failed delay on sound %s(%s) due to state validation",
						BuilderData.NickName,
						BuilderData.SoundId
					),
					2.0
				)
			end
		end

		-- Return...
		return
	end

	-- Handle normal auto-parry
	if not BuilderData.ShouldBlock and not BuilderData.ShouldRoll and not BuilderData.ParryRepeat then
		-- Run auto-parry
		AutoParry.RunParryFn()

		-- Notify user that animation has ended
		AutoParry.Notify(string.format("Activated on sound %s(%s)", BuilderData.NickName, BuilderData.SoundId), 2.0)

		-- Return...
		return
	end

	-- Handle dodging
	if BuilderData.ShouldRoll then
		-- Start dodging...
		AutoParry.RunDodgeFn(
			Entity,
			Pascal:GetConfig().AutoParry.ShouldRollCancel,
			Pascal:GetConfig().AutoParry.RollCancelDelay
		)

		-- Notify user that we have dodged
		AutoParry.Notify(string.format("Dodged sound %s(%s)", BuilderData.NickName, BuilderData.SoundId), 2.0)

		-- Return...
		return
	end
end

function AutoParry:OnAnimationPlayed(EntityData, AnimationTrack, Animation, Player, HumanoidRootPart, Humanoid)
	if not HumanoidRootPart then
		return
	end

	-- Ok, before we do anything... Let's check for these first.
	local LocalPlayerData = Helper.GetLocalPlayerWithData()
	if not LocalPlayerData or LocalPlayerData.Humanoid.Health <= 0 then
		return
	end

	local LeftHand = LocalPlayerData.Character:FindFirstChild("LeftHand")
	local RightHand = LocalPlayerData.Character:FindFirstChild("RightHand")
	if not LeftHand or not RightHand then
		return
	end

	local HandWeapon = LeftHand:FindFirstChild("HandWeapon") or RightHand:FindFirstChild("HandWeapon")
	if not HandWeapon then
		return
	end

	if not Pascal:GetConfig().AutoParry.Enabled then
		return
	end

	if LocalPlayerData.Player == Player and not Pascal:GetConfig().AutoParry.LocalAttackAutoParry then
		return
	end

	-- Get animation builder data
	local BuilderData = AutoParry:GetBuilderData("Animation", Animation.AnimationId)
	if not BuilderData then
		return
	end

	-- Save start timestamp...
	local StartTimeStamp = Pascal:GetMethods().ExecutionClock()

	-- Get animation data (this should always work)
	local AnimationData = AutoParry:EmplaceAnimationToData(EntityData, AnimationTrack, Animation.AnimationId)
	if not AnimationData then
		return
	end

	-- Check if we have activate on end on...
	if BuilderData.ActivateOnEnd then
		AutoParry.Notify(
			string.format(
				"Delaying on animation %s(%s) until animation ends...",
				BuilderData.NickName,
				BuilderData.AnimationId
			),
			2.0
		)

		-- Wait until animation end...
		repeat
			Pascal:GetMethods().Wait()
		until not AnimationTrack.IsPlaying
	end

	-- Validate current auto-parry state is OK
	if
		not AutoParry.ValidateState(
			AnimationTrack,
			BuilderData,
			LocalPlayerData,
			HumanoidRootPart,
			Humanoid,
			Player,
			false,
			false,
			true
		)
	then
		return
	end

	-- Randomize seed according to the timestamp (ms)
	Pascal:GetMethods().RandomSeed(DateTime.now().UnixTimestampMillis)

	-- Check hitchance
	if Pascal:GetMethods().Random(0.0, 100.0) > Pascal:GetConfig().AutoParry.Hitchance then
		return
	end

	-- Calculate delay(s)
	local function CalculateCurrentDelay()
		local OutOfRangeAccountFor = AutoParry.TimeWhenOutOfRange
				and Pascal:GetMethods().Max(Pascal:GetMethods().ExecutionClock() - AutoParry.TimeWhenOutOfRange, 0.0)
			or 0.0

		local AttemptMilisecondsConvertedToSeconds = Pascal:GetMethods().ToNumber(BuilderData.AttemptDelay)
				and Pascal:GetMethods().ToNumber(BuilderData.AttemptDelay) / 1000
			or 0

		local RepeatMilisecondsConvertedToSeconds = Pascal:GetMethods().ToNumber(BuilderData.ParryRepeatDelay)
				and Pascal:GetMethods().ToNumber(BuilderData.ParryRepeatDelay) / 1000
			or 0

		-- Delay(s) accounting for out of range time...
		AttemptMilisecondsConvertedToSeconds = AttemptMilisecondsConvertedToSeconds - OutOfRangeAccountFor
		RepeatMilisecondsConvertedToSeconds = RepeatMilisecondsConvertedToSeconds - OutOfRangeAccountFor

		-- Delay(s) accounting for global delay...
		AttemptMilisecondsConvertedToSeconds = AttemptMilisecondsConvertedToSeconds
			+ ((Pascal:GetConfig().AutoParry.AdjustTimingsBySlider / 1000) or 0)

		RepeatMilisecondsConvertedToSeconds = RepeatMilisecondsConvertedToSeconds
			+ ((Pascal:GetConfig().AutoParry.AdjustTimingsBySlider / 1000) or 0)

		-- Ping converted to two decimal places...
		local PingAdjustmentAmount = Pascal:GetMethods()
			.Max(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000, 0.0) * Pascal:GetMethods().Clamp(
			((Pascal:GetConfig().AutoParry.PingAdjust or 0) / 100),
			0.0,
			1.0
		)

		local RepeatDelayAccountingForPingAdjustment = Pascal:GetMethods()
			.Max(RepeatMilisecondsConvertedToSeconds - PingAdjustmentAmount, 0.0)

		local AttemptDelayAccountingForPingAdjustment =
			Pascal:GetMethods().Max(AttemptMilisecondsConvertedToSeconds - PingAdjustmentAmount, 0.0)

		-- Reset time when out of range...
		AutoParry.TimeWhenOutOfRange = nil

		return {
			AttemptDelay = AttemptDelayAccountingForPingAdjustment,
			RepeatDelay = RepeatDelayAccountingForPingAdjustment,
		}
	end

	local function CheckForAnimationFeint()
		Helper.TryAndCatch(
			-- Try...
			function()
				-- Reset flag...
				if AutoParry.AnimationFeint then
					AutoParry.AnimationFeint = false
				end

				-- Wait until animation ends...
				repeat
					Pascal:GetMethods().Wait()
				until not AnimationTrack.IsPlaying

				-- Check if the parry sound is playing...
				local Parried = AutoParry.FindSound(LocalPlayerData.HumanoidRootPart, "Parried")
				if Parried and Parried.IsPlaying then
					return false
				end

				-- Calculate feint threshold...
				local Threshold = math.clamp(AnimationTrack.Length / AnimationTrack.Speed, 0.0, 10.0)
				if AnimationTrack.Length == 0 then
					Threshold = 0.3
				end

				-- Lessen threshold by a factor (tis magic)...
				Threshold = Threshold * 0.75

				-- Check if the difference between the start and end is too long...
				local StartEndDifference = Pascal:GetMethods().ExecutionClock() - StartTimeStamp
				if (StartEndDifference * 10) > Threshold then
					return false
				end

				-- Flag...
				AutoParry.AnimationFeint = true

				-- It is a feint...
				return AutoParry.OnAnimationFeint(LocalPlayerData, HumanoidRootPart, Player)
			end,

			-- Catch...
			function(Error)
				Pascal:GetLogger():Print("AutoParry.CheckForAnimationFeint - Caught exception: %s", Error)
			end
		)
	end

	-- Spawn a task that checks for feints...
	task.spawn(CheckForAnimationFeint)

	-- Get delay
	local CurrentDelay = CalculateCurrentDelay()

	-- Set that we are running
	AutoParry.IsAutoParryRunning = true

	-- Notify
	AutoParry.Notify(
		string.format(
			"Delaying on animation %s(%s) for %.3f seconds",
			BuilderData.NickName,
			BuilderData.AnimationId,
			CurrentDelay.AttemptDelay
		),
		2.0
	)

	-- Wait for delay to occur
	local DelayResult = AutoParry.DelayAndValidateStateFn(
		CurrentDelay.AttemptDelay,
		AnimationTrack,
		BuilderData,
		LocalPlayerData,
		HumanoidRootPart,
		Humanoid,
		Player,
		false,
		"Animation"
	)

	if not DelayResult then
		-- Notify user that delay has failed
		AutoParry.Notify(
			string.format(
				"Failed delay on animation %s(%s) due to state validation",
				BuilderData.NickName,
				BuilderData.AnimationId
			),
			2.0
		)

		return
	end

	-- Set that we are not running
	AutoParry.IsAutoParryRunning = false

	if
		BuilderData.ParryRepeat
		and not BuilderData.ShouldBlock
		and not BuilderData.ShouldRoll
		and BuilderData.ParryRepeatAnimationEnds
	then
		local RepeatIndex = 0

		repeat
			-- Get delay
			local CurrentDelay = CalculateCurrentDelay()

			-- Parry
			AutoParry.RunParryFn()

			-- Notify user that animation has repeated
			AutoParry.Notify(
				string.format(
					"(%i) Activated on animation %s(%s) (%s: %.3f seconds)",
					RepeatIndex,
					BuilderData.NickName,
					BuilderData.AnimationId,
					RepeatDelayResult and "repeat-delay" or "delay",
					RepeatDelayResult and CurrentDelay.RepeatDelay or CurrentDelay.AttemptDelay
				),
				2.0
			)

			-- Set that we are running
			AutoParry.IsAutoParryRunning = true

			-- Wait for delay to occur
			RepeatDelayResult = AutoParry.DelayAndValidateStateFn(
				CurrentDelay.RepeatDelay,
				AnimationTrack,
				BuilderData,
				LocalPlayerData,
				HumanoidRootPart,
				Humanoid,
				Player,
				true,
				"Animation"
			)

			-- Set that we are not running
			AutoParry.IsAutoParryRunning = false

			if not RepeatDelayResult then
				-- Notify user that delay has failed
				AutoParry.Notify(
					string.format(
						"Failed delay on animation %s(%s) due to state validation",
						BuilderData.NickName,
						BuilderData.AnimationId
					),
					2.0
				)
			end

			-- Increment index
			RepeatIndex = RepeatIndex + 1
		until not AnimationTrack.IsPlaying

		return
	end

	-- Handle auto-parry repeats
	if
		BuilderData.ParryRepeat
		and not BuilderData.ShouldBlock
		and not BuilderData.ShouldRoll
		and not BuilderData.ParryRepeatAnimationEnds
	then
		local RepeatDelayResult = nil

		-- Loop how many times we need to repeat...
		for RepeatIndex = 0, (BuilderData.ParryRepeatTimes or 0) do
			-- Get delay
			local CurrentDelay = CalculateCurrentDelay()

			-- Parry
			AutoParry.RunParryFn()

			-- Notify user that animation has repeated
			AutoParry.Notify(
				string.format(
					"(%i) Activated on animation %s(%s) (%s: %.3f seconds)",
					RepeatIndex,
					BuilderData.NickName,
					BuilderData.AnimationId,
					RepeatDelayResult and "repeat-delay" or "delay",
					RepeatDelayResult and CurrentDelay.RepeatDelay or CurrentDelay.AttemptDelay
				),
				2.0
			)

			-- Set that we are running
			AutoParry.IsAutoParryRunning = true

			-- Wait for delay to occur
			RepeatDelayResult = AutoParry.DelayAndValidateStateFn(
				CurrentDelay.RepeatDelay,
				AnimationTrack,
				BuilderData,
				LocalPlayerData,
				HumanoidRootPart,
				Humanoid,
				Player,
				true
			)

			-- Set that we are not running
			AutoParry.IsAutoParryRunning = false

			if not RepeatDelayResult then
				-- Notify user that delay has failed
				AutoParry.Notify(
					string.format(
						"Failed delay on animation %s(%s) due to state validation",
						BuilderData.NickName,
						BuilderData.AnimationId
					),
					2.0
				)
			end
		end

		-- Return...
		return
	end

	-- Handle normal auto-parry
	if not BuilderData.ShouldBlock and not BuilderData.ShouldRoll and not BuilderData.ParryRepeat then
		-- Run auto-parry
		AutoParry.RunParryFn()

		-- Notify user that animation has ended
		AutoParry.Notify(
			string.format("Activated on animation %s(%s)", BuilderData.NickName, BuilderData.AnimationId),
			2.0
		)

		-- Return...
		return
	end

	-- Handle blocking
	if BuilderData.ShouldBlock then
		-- Start blocking
		AutoParry.StartBlockFn()

		-- Notify user that blocking has started
		AutoParry.Notify(
			string.format("Started blocking on animation %s(%s)", BuilderData.NickName, BuilderData.AnimationId),
			2.0
		)

		-- Set animation data that we started blocking
		AnimationData.StartedBlocking = true

		-- Start blocking state...
		AutoParry.StartedBlocking = true

		-- Spawn task...
		task.spawn(function()
			-- Wait until animation ends...
			repeat
				task.wait()
			until not AnimationTrack.IsPlaying

			-- End blocking
			AutoParry.EndBlockFn()

			-- End blocking state
			AnimationData.StartedBlocking = false

			-- Stop blocking state...
			AutoParry.StartedBlocking = false

			-- Notify user that blocking has stopped
			AutoParry.Notify(
				string.format("Ended blocking on animation %s(%s)", BuilderData.NickName, BuilderData.AnimationId),
				2.0
			)
		end)

		-- Return...
		return
	end

	-- Handle dodging
	if BuilderData.ShouldRoll then
		-- Start dodging...
		AutoParry.RunDodgeFn(
			Entity,
			Pascal:GetConfig().AutoParry.ShouldRollCancel,
			Pascal:GetConfig().AutoParry.RollCancelDelay
		)

		-- Notify user that we have dodged
		AutoParry.Notify(string.format("Dodged animation %s(%s)", BuilderData.NickName, BuilderData.AnimationId), 2.0)

		-- Return...
		return
	end
end

function AutoParry.OnAnimationFeint(LocalPlayerData, HumanoidRootPart, Player)
	if not LocalPlayerData.HumanoidRootPart or not HumanoidRootPart then
		return
	end

	-- Check if we are supposed to be doing this
	if not Pascal:GetConfig().AutoParry.RollOnFeints then
		return
	end

	-- Check feint distance
	if
		not AutoParry.CheckDistanceBetweenParts({
			MinimumDistance = Pascal:GetConfig().AutoParry.MinimumFeintDistance,
			MaximumDistance = Pascal:GetConfig().AutoParry.MaximumFeintDistance,
		}, HumanoidRootPart, LocalPlayerData.HumanoidRootPart) and Player ~= LocalPlayerData.Player
	then
		return
	end

	-- Check if players are facing each-other
	if
		not AutoParry.CheckFacingThresholdOnPlayers(LocalPlayerData, HumanoidRootPart)
		and Player ~= LocalPlayerData.Player
	then
		return
	end

	-- Effect handling...
	local EffectReplicator = Pascal:GetEffectReplicator()

	-- Check if we can roll
	if
		not AutoParry.CanRoll(LocalPlayerData, HumanoidRootPart, EffectReplicator)
		and Player ~= LocalPlayerData.Player
	then
		-- Wait until we can roll
		repeat
			Pascal:GetMethods().Wait()
		until not AutoParry.CanRoll(LocalPlayerData, HumanoidRootPart, EffectReplicator)
			and Player ~= LocalPlayerData.Player
	end

	-- Looks like we already caught a feint...
	if AutoParry.SoundFeint or AutoParry.AnimationFeint then
		return
	end

	-- Notify user...
	AutoParry.Notify("Caught animation-feint, dodging feint...", 2.0)

	-- Start dodging...
	AutoParry.RunDodgeFn(
		Entity,
		Pascal:GetConfig().AutoParry.ShouldRollCancel,
		Pascal:GetConfig().AutoParry.RollCancelDelay
	)

	-- Notify user...
	AutoParry.Notify("Successfully dodged animation-feint...", 2.0)
end

function AutoParry.OnFeintSound(LocalPlayerData, HumanoidRootPart, Player)
	if not LocalPlayerData.HumanoidRootPart or not HumanoidRootPart then
		return
	end

	-- Check if we are supposed to be doing this
	if not Pascal:GetConfig().AutoParry.RollOnFeints then
		return
	end

	-- Check feint distance
	if
		not AutoParry.CheckDistanceBetweenParts({
			MinimumDistance = Pascal:GetConfig().AutoParry.MinimumFeintDistance,
			MaximumDistance = Pascal:GetConfig().AutoParry.MaximumFeintDistance,
		}, HumanoidRootPart, LocalPlayerData.HumanoidRootPart) and Player ~= LocalPlayerData.Player
	then
		return
	end

	-- Check if players are facing each-other
	if
		not AutoParry.CheckFacingThresholdOnPlayers(LocalPlayerData, HumanoidRootPart)
		and Player ~= LocalPlayerData.Player
	then
		return
	end

	-- Effect handling...
	local EffectReplicator = Pascal:GetEffectReplicator()

	-- Check if we can roll
	if
		not AutoParry.CanRoll(LocalPlayerData, HumanoidRootPart, EffectReplicator)
		and Player ~= LocalPlayerData.Player
	then
		-- Wait until we can roll
		repeat
			Pascal:GetMethods().Wait()
		until not AutoParry.CanRoll(LocalPlayerData, HumanoidRootPart, EffectReplicator)
			and Player ~= LocalPlayerData.Player
	end

	-- Looks like we already caught a feint...
	if AutoParry.SoundFeint or AutoParry.AnimationFeint then
		return
	end

	-- Notify user...
	AutoParry.Notify("Caught sound-feint, dodging feint...", 2.0)

	-- Flag...
	AutoParry.SoundFeint = true

	-- Start dodging...
	AutoParry.RunDodgeFn(
		Entity,
		Pascal:GetConfig().AutoParry.ShouldRollCancel,
		Pascal:GetConfig().AutoParry.RollCancelDelay,
		true
	)

	-- Notify user...
	AutoParry.Notify("Successfully dodged sound-feint...", 2.0)
end

function AutoParry.OnFeintSoundEnd()
	-- Remove flag...
	if AutoParry.SoundFeint then
		AutoParry.SoundFeint = false
	end
end

function AutoParry.Disconnect()
	-- Disconnect, remove entity connections...
	Helper.LoopLuaTable(AutoParry.Connections, function(Entity, Table)
		-- Disconnect connections...
		Helper.LoopLuaTable(Table, function(Index, Connection)
			Connection:Disconnect()
		end)

		-- Remove entity table...
		AutoParry.Connections[Entity] = nil
	end)

	-- Disconnect, remove other connections...
	Helper.LoopLuaTable(AutoParry.OtherConnections, function(Index, Connection)
		-- Disconnect connection...
		Connection:Disconnect()

		-- Remove index...
		AutoParry.OtherConnections[Index] = nil
	end)

	-- Disconnect, remove other connections...
	Helper.LoopLuaTable(AutoParry.SoundConnections, function(Sound, Connection)
		-- Disconnect connection...
		Connection:Disconnect()

		-- Remove sound index...
		AutoParry.SoundConnections[Sound] = nil
	end)

	-- Remove conenction table(s)...
	AutoParry.Connections = nil
	AutoParry.OtherConnections = nil
	AutoParry.SoundConnections = nil
end

function AutoParry.FindSound(HumanoidRootPart, Name)
	local SoundFromHumanoidRootPart = HumanoidRootPart:FindFirstChild(Name)
	if SoundFromHumanoidRootPart then
		return SoundFromHumanoidRootPart
	end

	local SoundsFolder = HumanoidRootPart:FindFirstChild("Sounds")
	if not SoundsFolder then
		return nil
	end

	return SoundsFolder:FindFirstChild(Name)
end

function AutoParry.GetThrownProjectiles()
	local Thrown = WorkspaceService:WaitForChild("Thrown")
	table.insert(
		AutoParry.OtherConnections,
		Thrown.DescendantAdded:Connect(function(Descendant)
			Helper.TryAndCatch(
				-- Try...
				function()
					if typeof(Descendant) ~= "Instance" then
						return false
					end

					if not Descendant:IsA("BasePart") and not Descendant:IsA("Attachment") then
						return false
					end

					local LocalPlayerData = Helper.GetLocalPlayerWithData()
					if not LocalPlayerData then
						return
					end

					-- Dummy markers...
					local DummyMarkerTwo = false

					local Entity = Descendant:FindFirstAncestorWhichIsA("Model")
					local HumanoidRootPart = Entity and Entity:FindFirstChild("HumanoidRootPart") or nil
					if not Entity or not HumanoidRootPart then
						-- Create a dummy entity...
						Entity = Descendant.Parent
						if not Entity then
							return
						end

						-- Set a dummy humanoid-root-part...
						HumanoidRootPart = Descendant
					end

					local Humanoid = Entity:FindFirstChild("Humanoid")
					if not Humanoid then
						-- Create a dummy humanoid...
						Humanoid = Instance.new("Humanoid")
						Humanoid.Health = math.huge

						-- Marker two...
						DummyMarkerTwo = true
					end

					-- Call OnPart for AutoParryLogger...
					AutoParryLogger:OnPart(nil, Entity, Descendant, HumanoidRootPart, LocalPlayerData, Descendant)

					-- Get builder data...
					local BuilderData = AutoParry:GetBuilderData("Part", Descendant.Name)
					if not BuilderData then
						return false
					end

					-- Wait until in range...
					repeat
						task.wait()
					until AutoParry.CheckDistanceBetweenParts(
							BuilderData,
							HumanoidRootPart,
							LocalPlayerData.HumanoidRootPart
						)

					-- Call OnPartInRange for AutoParry...
					AutoParry:OnPartInRange(Entity, Descendant, nil, HumanoidRootPart, Humanoid)

					-- Destroy our created instances (if we created them...)
					if DummyMarkerTwo then
						Humanoid:Destroy()
					end
				end,

				-- Catch...
				function()
					Pascal:GetLogger():Print(
						"AutoParry (ThrownDescendantProjectile) (%s) - Caught exception: %s",
						Descendant.Name or "",
						Error
					)
				end
			)
		end)
	)

	Helper.LoopInstanceDescendants(Thrown, function(Index, Descendant)
		Helper.TryAndCatch(
			-- Try...
			function()
				if typeof(Descendant) ~= "Instance" then
					return false
				end

				if not Descendant:IsA("BasePart") and not Descendant:IsA("Attachment") then
					return false
				end

				local LocalPlayerData = Helper.GetLocalPlayerWithData()
				if not LocalPlayerData then
					return
				end

				-- Dummy markers...
				local DummyMarkerTwo = false

				local Entity = Descendant:FindFirstAncestorWhichIsA("Model")
				local HumanoidRootPart = Entity and Entity:FindFirstChild("HumanoidRootPart") or nil
				if not Entity or not HumanoidRootPart then
					-- Create a dummy entity...
					Entity = Descendant.Parent
					if not Entity then
						return
					end

					-- Set a dummy humanoid-root-part...
					HumanoidRootPart = Descendant
				end

				local Humanoid = Entity:FindFirstChild("Humanoid")
				if not Humanoid then
					-- Create a dummy humanoid...
					Humanoid = Instance.new("Humanoid")
					Humanoid.Health = math.huge

					-- Marker two...
					DummyMarkerTwo = true
				end

				-- Call OnPart for AutoParryLogger...
				AutoParryLogger:OnPart(nil, Entity, Descendant, HumanoidRootPart, LocalPlayerData, Descendant)

				-- Get builder data...
				local BuilderData = AutoParry:GetBuilderData("Part", Descendant.Name)
				if not BuilderData then
					return false
				end

				task.spawn(function()
					-- Wait until in range...
					repeat
						task.wait()
					until AutoParry.CheckDistanceBetweenParts(
							BuilderData,
							HumanoidRootPart,
							LocalPlayerData.HumanoidRootPart
						)

					-- Call OnPartInRange for AutoParry...
					AutoParry:OnPartInRange(Entity, Descendant, nil, HumanoidRootPart, Humanoid)

					-- Destroy our created instances (if we created them...)
					if DummyMarkerTwo then
						Humanoid:Destroy()
					end
				end)
			end,

			-- Catch...
			function(Error)
				Pascal:GetLogger()
					:Print("AutoParry (ThrownLoopPart) (%s) - Caught exception: %s", Descendant.Name or "", Error)
			end
		)
	end)
end

function AutoParry.GetWorkspaceSounds()
	table.insert(
		AutoParry.OtherConnections,
		WorkspaceService.DescendantRemoving:Connect(function(Descendant)
			Helper.TryAndCatch(
				-- Try...
				function()
					if typeof(Descendant) ~= "Instance" or (not Descendant:IsA("Sound")) then
						return false
					end

					if not AutoParry.SoundConnections[Descendant] then
						return
					end

					-- Disconnect his connection...
					AutoParry.SoundConnections[Descendant]:Disconnect()

					-- Remove descendant index...
					AutoParry.SoundConnections[Descendant] = nil
				end,

				-- Catch...
				function(Error)
					Pascal:GetLogger()
						:Print("AutoParry (DescendantRemoving) (%s) - Caught exception: %s", Descendant, Error)
				end
			)
		end)
	)

	table.insert(
		AutoParry.OtherConnections,
		WorkspaceService.DescendantAdded:Connect(function(Descendant)
			Helper.TryAndCatch(
				-- Try...
				function()
					if typeof(Descendant) ~= "Instance" or (not Descendant:IsA("Sound")) then
						return false
					end

					-- Do not allow more than one connection...
					if AutoParry.SoundConnections[Descendant] then
						-- Remove connection...
						AutoParry.SoundConnections[Descendant]:Disconnect()

						-- Remove entity table...
						AutoParry.SoundConnections[Descendant] = nil
					end

					-- Create entity connection table...
					AutoParry.SoundConnections[Descendant] = Descendant.Played:Connect(function(SoundId)
						Helper.TryAndCatch(
							-- Try...
							function()
								local LocalPlayerData = Helper.GetLocalPlayerWithData()
								if not LocalPlayerData then
									return
								end

								-- Dummy markers...
								local DummyMarkerOne = false
								local DummyMarkerTwo = false

								local Entity = Descendant:FindFirstAncestorWhichIsA("Model")
								local HumanoidRootPart = Entity and Entity:FindFirstChild("HumanoidRootPart") or nil
								if not Entity or not HumanoidRootPart then
									-- Create a dummy entity...
									Entity = Descendant.Parent
									if not Entity then
										return
									end

									-- Create a dummy humanoid-root-part...
									HumanoidRootPart = Instance.new("Part")
									HumanoidRootPart.Position = LocalPlayerData.HumanoidRootPart.Position

									-- Marker one...
									DummyMarkerOne = true
								end

								local Humanoid = Entity:FindFirstChild("Humanoid")
								if not Humanoid then
									-- Create a dummy humanoid...
									Humanoid = Instance.new("Humanoid")
									Humanoid.Health = math.huge

									-- Marker two...
									DummyMarkerTwo = true
								end

								-- Call OnSoundPlayed for AutoParry...
								AutoParry:OnSoundPlayed(nil, Descendant, nil, HumanoidRootPart, Humanoid)

								-- Call OnSoundPlayed for AutoParryLogger...
								AutoParryLogger:OnSoundPlayed(
									nil,
									Entity,
									HumanoidRootPart,
									LocalPlayerData,
									Descendant
								)

								-- Destroy our created instances (if we created them...)
								if DummyMarkerOne then
									HumanoidRootPart:Destroy()
								end

								if DummyMarkerTwo then
									Humanoid:Destroy()
								end
							end,

							-- Catch...
							function(Error)
								Pascal:GetLogger()
									:Print(
										"AutoParry (DescendantSound.Played) (%s) - Caught exception: %s",
										SoundId,
										Error
									)
							end
						)
					end)
				end,

				-- Catch...
				function(Error)
					Pascal:GetLogger()
						:Print("AutoParry (DescendantSoundOuter) (%s) - Caught exception: %s", SoundId, Error)
				end
			)
		end)
	)

	Helper.LoopInstanceDescendants(WorkspaceService, function(Index, Descendant)
		Helper.TryAndCatch(
			-- Try...
			function()
				if typeof(Descendant) ~= "Instance" or (not Descendant:IsA("Sound")) then
					return false
				end

				-- Do not allow more than one connection...
				if AutoParry.SoundConnections[Descendant] then
					-- Remove connection...
					AutoParry.SoundConnections[Descendant]:Disconnect()

					-- Remove entity table...
					AutoParry.SoundConnections[Descendant] = nil
				end

				AutoParry.SoundConnections[Descendant] = Descendant.Played:Connect(function(SoundId)
					Helper.TryAndCatch(
						-- Try...
						function()
							local LocalPlayerData = Helper.GetLocalPlayerWithData()
							if not LocalPlayerData then
								return
							end

							-- Dummy markers...
							local DummyMarkerOne = false
							local DummyMarkerTwo = false

							local Entity = Descendant:FindFirstAncestorWhichIsA("Model")
							local HumanoidRootPart = Entity and Entity:FindFirstChild("HumanoidRootPart") or nil
							if not Entity or not HumanoidRootPart then
								-- Create a dummy entity...
								Entity = Descendant.Parent
								if not Entity then
									return
								end

								-- Attempt to find something we can find a position off of...
								local Part = Descendant:FindFirstAncestorWhichIsA("Part")
									or Descendant:FindFirstAncestorWhichIsA("MeshPart")

								-- Create a dummy humanoid-root-part...
								HumanoidRootPart = Instance.new("Part")
								HumanoidRootPart.Position = Part and Part.Position
									or LocalPlayerData.HumanoidRootPart.Position

								-- Marker one...
								DummyMarkerOne = true
							end

							local Humanoid = Entity:FindFirstChild("Humanoid")
							if not Humanoid then
								-- Create a dummy humanoid...
								Humanoid = Instance.new("Humanoid")
								Humanoid.Health = math.huge

								-- Marker two...
								DummyMarkerTwo = true
							end

							-- Call OnSoundPlayed for AutoParry...
							AutoParry:OnSoundPlayed(nil, Descendant, nil, HumanoidRootPart, Humanoid)

							-- Call OnSoundPlayed for AutoParryLogger...
							AutoParryLogger:OnSoundPlayed(nil, Entity, HumanoidRootPart, LocalPlayerData, Descendant)

							-- Destroy our created instances (if we created them...)
							if DummyMarkerOne then
								HumanoidRootPart:Destroy()
							end

							if DummyMarkerTwo then
								Humanoid:Destroy()
							end
						end,

						-- Catch...
						function(Error)
							Pascal:GetLogger()
								:Print(
									"AutoParry (DescendantLoopSound.Played) (%s) - Caught exception: %s",
									SoundId,
									Error
								)
						end
					)
				end)
			end,

			-- Catch...
			function(Error)
				Pascal:GetLogger():Print("AutoParry (DescendantLoopOuter) (%s) - Caught exception: %s", SoundId, Error)
			end
		)
	end)
end

function AutoParry.OnLocalPlayerSwingSound()
	AutoParry.IsPlayerSwinging = false
end

function AutoParry.OnLocalPlayerSwingSoundEnd()
	AutoParry.IsPlayerSwinging = true
end

function AutoParry:OnEntityRemoved(Entity)
	if not AutoParry.Connections[Entity] then
		return
	end

	-- This entity was removed, remove his connections and his entity table...
	Helper.LoopLuaTable(AutoParry.Connections[Entity], function(Index, Connection)
		Connection:Disconnect()
	end)

	-- Remove entity table...
	AutoParry.Connections[Entity] = nil
end

function AutoParry:OnEntityAdded(Entity)
	local EntityData = AutoParry:EmplaceEntityToData(Entity)
	local Humanoid = Entity:WaitForChild("Humanoid", math.huge)
	local HumanoidRootPart = Entity:WaitForChild("HumanoidRootPart", math.huge)
	local Animator = Humanoid:WaitForChild("Animator", math.huge)

	if not AutoParry.Connections or not Entity then
		return
	end

	-- Do not allow more than one connection...
	if AutoParry.Connections[Entity] then
		-- Remove his connections and his entity table...
		Helper.LoopLuaTable(AutoParry.Connections[Entity], function(Index, Connection)
			Connection:Disconnect()
		end)

		-- Remove entity table...
		AutoParry.Connections[Entity] = nil
	end

	-- Create entity connection table...
	AutoParry.Connections[Entity] = AutoParry.Connections[Entity] or {}

	-- If this is the local-player, connect special event(s)...
	local Player = Players:GetPlayerFromCharacter(Entity)
	if Player == Players.LocalPlayer then
		local Swing1 = AutoParry.FindSound(HumanoidRootPart, "Swing1")
		local Swing2 = AutoParry.FindSound(HumanoidRootPart, "Swing2")
		if Swing1 or Swing2 then
			table.insert(AutoParry.Connections[Entity], Swing1.Played:Connect(AutoParry.OnLocalPlayerSwingSound))
			table.insert(AutoParry.Connections[Entity], Swing2.Played:Connect(AutoParry.OnLocalPlayerSwingSound))
			table.insert(AutoParry.Connections[Entity], Swing1.Ended:Connect(AutoParry.OnLocalPlayerSwingSoundEnd))
			table.insert(AutoParry.Connections[Entity], Swing2.Ended:Connect(AutoParry.OnLocalPlayerSwingSoundEnd))
		end
	end

	-- Connect event to OnFeintPlayed...
	local Feint = AutoParry.FindSound(HumanoidRootPart, "Feint")
	if Feint then
		table.insert(
			AutoParry.Connections[Entity],
			Feint.Played:Connect(function()
				Helper.TryAndCatch(
					-- Try...
					function()
						local HumanoidRootPart = Entity:FindFirstChild("HumanoidRootPart")
						if not HumanoidRootPart then
							return
						end

						local LocalPlayerData = Helper.GetLocalPlayerWithData()
						if not LocalPlayerData then
							return
						end

						if
							not Pascal:GetConfig().AutoParry.LocalAttackAutoParry
							and Player == LocalPlayerData.Player
						then
							return
						end

						AutoParry.OnFeintSound(LocalPlayerData, HumanoidRootPart, Player)
					end,

					-- Catch...
					function(Error)
						Pascal:GetLogger():Print("AutoParry.OnFeintSound - Caught exception: %s", Error)
					end
				)
			end)
		)

		table.insert(
			AutoParry.Connections[Entity],
			Feint.Ended:Connect(function()
				Helper.TryAndCatch(
					-- Try...
					function()
						AutoParry.OnFeintSoundEnd()
					end,

					-- Catch...
					function(Error)
						Pascal:GetLogger():Print("AutoParry.OnFeintSoundEnd - Caught exception: %s", Error)
					end
				)
			end)
		)
	end

	-- Connect event(s) to OnProjectileInRange...
	table.insert(
		AutoParry.Connections[Entity],
		Entity.DescendantAdded:Connect(function(Descendant)
			Helper.TryAndCatch(
				-- Try...
				function()
					if typeof(Descendant) ~= "Instance" then
						return false
					end

					if not Descendant:IsA("BasePart") and not Descendant:IsA("Attachment") then
						return false
					end

					local LocalPlayerData = Helper.GetLocalPlayerWithData()
					if not LocalPlayerData then
						return
					end

					-- Dummy markers...
					local DummyMarkerTwo = false

					local Entity = Descendant:FindFirstAncestorWhichIsA("Model")
					local HumanoidRootPart = Entity and Entity:FindFirstChild("HumanoidRootPart") or nil
					if not Entity or not HumanoidRootPart then
						-- Create a dummy entity...
						Entity = Descendant.Parent
						if not Entity then
							return
						end

						-- Set a dummy humanoid-root-part...
						HumanoidRootPart = Descendant
					end

					local Humanoid = Entity:FindFirstChild("Humanoid")
					if not Humanoid then
						-- Create a dummy humanoid...
						Humanoid = Instance.new("Humanoid")
						Humanoid.Health = math.huge

						-- Marker two...
						DummyMarkerTwo = true
					end

					-- Call OnPart for AutoParryLogger...
					AutoParryLogger:OnPart(nil, Entity, Descendant, HumanoidRootPart, LocalPlayerData, Descendant)

					-- Get builder data...
					local BuilderData = AutoParry:GetBuilderData("Part", Descendant.Name)
					if not BuilderData then
						return false
					end

					-- Wait until in range...
					repeat
						task.wait()
					until AutoParry.CheckDistanceBetweenParts(
							BuilderData,
							HumanoidRootPart,
							LocalPlayerData.HumanoidRootPart
						)

					-- Call OnPartInRange for AutoParry...
					AutoParry:OnPartInRange(Entity, Descendant, nil, HumanoidRootPart, Humanoid)

					-- Destroy our created instances (if we created them...)
					if DummyMarkerTwo then
						Humanoid:Destroy()
					end
				end,

				-- Catch...
				function()
					Pascal:GetLogger()
						:Print(
							"AutoParry (EntityPartDescendant) (%s) - Caught exception: %s",
							Descendant.Name or "",
							Error
						)
				end
			)
		end)
	)

	Helper.LoopInstanceDescendants(Entity, function(Index, Descendant)
		Helper.TryAndCatch(
			-- Try...
			function()
				if typeof(Descendant) ~= "Instance" then
					return false
				end

				if not Descendant:IsA("BasePart") and not Descendant:IsA("Attachment") then
					return false
				end

				local LocalPlayerData = Helper.GetLocalPlayerWithData()
				if not LocalPlayerData then
					return
				end

				-- Dummy markers...
				local DummyMarkerTwo = false

				local Entity = Descendant:FindFirstAncestorWhichIsA("Model")
				local HumanoidRootPart = Entity and Entity:FindFirstChild("HumanoidRootPart") or nil
				if not Entity or not HumanoidRootPart then
					-- Create a dummy entity...
					Entity = Descendant.Parent
					if not Entity then
						return
					end

					-- Set a dummy humanoid-root-part...
					HumanoidRootPart = Descendant
				end

				local Humanoid = Entity:FindFirstChild("Humanoid")
				if not Humanoid then
					-- Create a dummy humanoid...
					Humanoid = Instance.new("Humanoid")
					Humanoid.Health = math.huge

					-- Marker two...
					DummyMarkerTwo = true
				end

				-- Call OnPart for AutoParryLogger...
				AutoParryLogger:OnPart(nil, Entity, Descendant, HumanoidRootPart, LocalPlayerData, Descendant)

				-- Get builder data...
				local BuilderData = AutoParry:GetBuilderData("Part", Descendant.Name)
				if not BuilderData then
					return false
				end

				task.spawn(function()
					-- Wait until in range...
					repeat
						task.wait()
					until AutoParry.CheckDistanceBetweenParts(
							BuilderData,
							HumanoidRootPart,
							LocalPlayerData.HumanoidRootPart
						)

					-- Call OnPartInRange for AutoParry...
					AutoParry:OnPartInRange(Entity, Descendant, nil, HumanoidRootPart, Humanoid)

					-- Destroy our created instances (if we created them...)
					if DummyMarkerTwo then
						Humanoid:Destroy()
					end
				end)
			end,

			-- Catch...
			function(Error)
				Pascal:GetLogger()
					:Print("AutoParry (EntityPartLoop) (%s) - Caught exception: %s", Descendant.Name or "", Error)
			end
		)
	end)

	-- Connect event(s) to OnAnimationPlayed & OnAnimationEnded...
	table.insert(
		AutoParry.Connections[Entity],
		Animator.AnimationPlayed:Connect(function(AnimationTrack)
			Helper.TryAndCatch(
				-- Try...
				function()
					local Humanoid = Entity:FindFirstChild("Humanoid")
					if not Humanoid then
						return
					end

					local HumanoidRootPart = Entity:FindFirstChild("HumanoidRootPart")
					if not HumanoidRootPart then
						return
					end

					local Animator = Humanoid:FindFirstChild("Animator")
					if not Animator then
						return
					end

					local LocalPlayerData = Helper.GetLocalPlayerWithData()
					if not LocalPlayerData then
						return
					end

					-- Call OnAnimationPlayed...
					AutoParry:OnAnimationPlayed(
						EntityData,
						AnimationTrack,
						AnimationTrack.Animation,
						Helper.GetPlayerFromEntity(Entity),
						HumanoidRootPart,
						Humanoid
					)

					-- Call OnAnimationPlayed for AutoParryLogger...
					AutoParryLogger:OnAnimationPlayed(Player, Entity, HumanoidRootPart, LocalPlayerData, AnimationTrack)
				end,

				-- Catch...
				function(Error)
					Pascal:GetLogger():Print("AutoParry (AnimationTrack.Played) - Caught exception: %s", Error)
				end
			)
		end)
	)
end

return AutoParry
