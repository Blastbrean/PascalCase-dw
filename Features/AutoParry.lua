-- Module
local AutoParry = {
	EntityData = {},
	Connections = {},
	PlayerFeint = {},
	CanLocalPlayerFeint = true,
	TimeWhenOutOfRange = nil,
}

-- Services
local Players = GetService("Players")
local WorkspaceService = GetService("Workspace")
local StatsService = GetService("Stats")

-- Requires
local Helper = require("Modules/Helpers/Helper")
local Pascal = require("Modules/Helpers/Pascal")
local AutoParryLogger = require("Features/AutoParryLogger")

function AutoParry.SimulateKeyFromKeyPress(KeyCode)
	-- Send key event
	Pascal:GetMethods().KeyPress(KeyCode)
end

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

function AutoParry.RunDodgeFn(Entity, ShouldRollCancel, RollCancelDelay)
	if Pascal:GetConfig().AutoParry.InputMethod == "KeyPress" then
		-- Run event to roll...
		AutoParry.SimulateKeyFromKeyPress(0x51)

		-- Check if we should roll cancel...
		if ShouldRollCancel then
			-- Calculate delay...
			local AttemptMilisecondsConvertedToSeconds = RollCancelDelay / 1000 or 0

			-- Notify user...
			Library:Notify(
				string.format("Delaying on roll-cancel for %.3f seconds...", AttemptMilisecondsConvertedToSeconds),
				2.0
			)

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

			-- End with notification
			Library:Notify("Successfully roll-cancelled...", 2.0)
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
			return
		end

		-- Check for the CharacterHandler & InputClient & Requests
		local CharacterHandler = LocalPlayerData.Character:FindFirstChild("CharacterHandler")
		if not CharacterHandler or not CharacterHandler:FindFirstChild("InputClient") then
			return
		end

		if not EffectReplicator:FindEffect("Action") and not EffectReplicator:FindEffect("Knocked") then
			AutoParry.SimulateKeyFromKeyPress(0x46)
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

function AutoParry.EndBlockingStates(PlayerData)
	Helper.LoopLuaTable(PlayerData.AnimationData, function(Index, AnimationData)
		if not AnimationData.StartedBlocking then
			return false
		end

		if AnimationData.AnimationTrack.IsPlaying then
			return false
		end

		-- Get animation builder data
		local BuilderData = AutoParry:GetBuilderData(AnimationData.AnimationTrack.Animation.AnimationId)
		if not BuilderData then
			return false
		end

		-- End blocking
		AutoParry.EndBlockFn()

		-- End blocking state
		AnimationData.StartedBlocking = false

		-- Notify user that blocking has stopped
		Library:Notify(
			string.format("Ended blocking on animation %s(%s)", BuilderData.NickName, BuilderData.AnimationId),
			2.0
		)
	end)
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
	FirstTime
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
			Library:Notify("Player went out of range, delaying until in range...", 2.0)

			-- Save time to account for delay later...
			AutoParry.TimeWhenOutOfRange = Pascal:GetMethods().ExecutionClock()

			repeat
				Pascal:GetMethods().Wait()
			until AutoParry.CheckDistanceBetweenParts(BuilderData, HumanoidRootPart, LocalPlayerData.HumanoidRootPart)

			-- Resume...
			Library:Notify("Back in range, resuming auto-parry...", 2.0)
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

	if not Pascal:GetMethods().IsWindowActive() then
		-- Notify user that we cannot run auto-parry
		Library:Notify("Cannot run auto-parry, the window is not active...", 2.0)
		return false
	end

	-- Effect handling...
	local EffectReplicator = Pascal:GetEffectReplicator()

	-- If we're currently attacking we are unable to parry!
	local InsideOfAttack = EffectReplicator:FindEffect("LightAttack")
		and not EffectReplicator:FindEffect("OffhandAttack")

	local CurrentlyInAction = EffectReplicator:FindEffect("Action") or EffectReplicator:FindEffect("MobileAction")

	if
		not SkipCheckForAttacking
		and not Pascal:GetConfig().AutoParry.AutoFeint
		and not AutoParry.CanLocalPlayerFeint
		and (InsideOfAttack or CurrentlyInAction)
		and Player ~= LocalPlayerData.Player
	then
		return false
	end

	if
		Pascal:GetConfig().AutoParry.AutoFeint
		and (InsideOfAttack or CurrentlyInAction)
		and AutoParry.CanLocalPlayerFeint
		and Player ~= LocalPlayerData.Player
	then
		-- Notify user that we have triggered auto-feint
		Library:Notify(
			string.format("Triggered auto-feint on %s(%s)", BuilderData.NickName, BuilderData.AnimationId),
			2.0
		)

		-- Run feint function...
		AutoParry.RunFeintFn()
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
		Library:Notify(
			string.format("Cannot dodge on animation %s(%s)", BuilderData.NickName, BuilderData.AnimationId),
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
	if not AnimationTrack.IsPlaying then
		return false
	end

	-- Did this player feint?
	if AutoParry.PlayerFeint[Player] then
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
	SkipCheckForAttacking
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
			false
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
			true
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

function AutoParry:GetBuilderData(AnimationId)
	-- Builder settings list
	local BuilderSettingsList = Pascal:GetConfig().AutoParryBuilder.BuilderSettingsList
	return BuilderSettingsList[AnimationId]
end

function AutoParry:OnAnimationEnded(EntityData)
	-- Handle activate on end for auto parry
	AutoParry:MainAutoParry(EntityData, AnimationTrack, Animation, Player, HumanoidRootPart, Humanoid, true)

	-- Handle block states for player data
	AutoParry.EndBlockingStates(EntityData)
end

function AutoParry:MainAutoParry(
	EntityData,
	AnimationTrack,
	Animation,
	Player,
	HumanoidRootPart,
	Humanoid,
	IsEndAnimation
)
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
	local BuilderData = AutoParry:GetBuilderData(Animation.AnimationId)
	if not BuilderData then
		return
	end

	-- Get animation data (this should always work)
	local AnimationData = AutoParry:EmplaceAnimationToData(EntityData, AnimationTrack, Animation.AnimationId)
	if not AnimationData then
		return
	end

	-- Check if we have activate on end on...
	if BuilderData.ActivateOnEnd and not IsEndAnimation then
		return
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

	-- Notify user that animation has started
	if not IsEndAnimation then
		-- Get delay
		local CurrentDelay = CalculateCurrentDelay()

		-- Notify
		Library:Notify(
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
			false
		)

		if not DelayResult then
			-- Notify user that delay has failed
			Library:Notify(
				string.format(
					"Failed delay on animation %s(%s) due to state validation",
					BuilderData.NickName,
					BuilderData.AnimationId
				),
				2.0
			)

			return
		end
	end

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
			Library:Notify(
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

			if not RepeatDelayResult and not IsEndAnimation then
				-- Notify user that delay has failed
				Library:Notify(
					string.format(
						"Failed delay on animation %s(%s) due to state validation",
						BuilderData.NickName,
						BuilderData.AnimationId
					),
					2.0
				)

				return
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
			Library:Notify(
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

			if not RepeatDelayResult and not IsEndAnimation then
				-- Notify user that delay has failed
				Library:Notify(
					string.format(
						"Failed delay on animation %s(%s) due to state validation",
						BuilderData.NickName,
						BuilderData.AnimationId
					),
					2.0
				)

				return
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
		Library:Notify(
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
		Library:Notify(
			string.format("Started blocking on animation %s(%s)", BuilderData.NickName, BuilderData.AnimationId),
			2.0
		)

		-- Set animation data that we started blocking
		AnimationData.StartedBlocking = true

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
		Library:Notify(string.format("Dodged animation %s(%s)", BuilderData.NickName, BuilderData.AnimationId), 2.0)

		-- Return...
		return
	end
end

function AutoParry:OnAnimationPlayed(EntityData, AnimationTrack, Animation, Player, HumanoidRootPart, Humanoid)
	AutoParry:MainAutoParry(EntityData, AnimationTrack, Animation, Player, HumanoidRootPart, Humanoid, false)
end

function AutoParry.OnPlayerFeint(LocalPlayerData, HumanoidRootPart, Player)
	if not Player or not LocalPlayerData.HumanoidRootPart or not HumanoidRootPart then
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
		-- Notify user...
		Library:Notify(string.format("Caught feint on player %s, unable to dodge...", Player.Name), 2.0)
		return
	end

	-- Notify user...
	Library:Notify(string.format("Caught feint on player %s, dodging feint...", Player.Name), 2.0)

	-- Start dodging...
	AutoParry.RunDodgeFn(
		Entity,
		Pascal:GetConfig().AutoParry.ShouldRollCancel,
		Pascal:GetConfig().AutoParry.RollCancelDelay
	)

	-- Notify user...
	Library:Notify(string.format("Successfully dodged feint on player %s", Player.Name), 2.0)

	-- Flag player...
	AutoParry.PlayerFeint[Player] = true
end

function AutoParry.OnPlayerFeintEnd(Player)
	AutoParry.PlayerFeint[Player] = false
end

function AutoParry.OnLocalPlayerSwingSound()
	AutoParry.CanLocalPlayerFeint = false
end

function AutoParry.OnLocalPlayerSwingSoundEnd()
	AutoParry.CanLocalPlayerFeint = true
end

function AutoParry.Disconnect()
	Helper.LoopLuaTable(AutoParry.Connections, function(Index, Connection)
		Connection:Disconnect()
	end)
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

function AutoParry:OnEntityAdded(Entity)
	local EntityData = AutoParry:EmplaceEntityToData(Entity)
	if not EntityData then
		return
	end

	local Humanoid = Entity:WaitForChild("Humanoid", math.huge)
	if not Humanoid then
		return
	end

	local HumanoidRootPart = Entity:WaitForChild("HumanoidRootPart", math.huge)
	if not HumanoidRootPart then
		return
	end

	local Animator = Humanoid:WaitForChild("Animator", math.huge)
	if not Animator then
		return
	end

	-- If this is the local-player, connect special event(s)...
	local Player = Players:GetPlayerFromCharacter(Entity)
	if Player == Players.LocalPlayer then
		local Swing1 = AutoParry.FindSound(HumanoidRootPart, "Swing1")
		local Swing2 = AutoParry.FindSound(HumanoidRootPart, "Swing2")
		if Swing1 or Swing2 then
			table.insert(AutoParry.Connections, Swing1.Played:Connect(AutoParry.OnLocalPlayerSwingSound))
			table.insert(AutoParry.Connections, Swing2.Played:Connect(AutoParry.OnLocalPlayerSwingSound))
			table.insert(AutoParry.Connections, Swing1.Ended:Connect(AutoParry.OnLocalPlayerSwingSoundEnd))
			table.insert(AutoParry.Connections, Swing2.Ended:Connect(AutoParry.OnLocalPlayerSwingSoundEnd))
		end
	end

	-- Connect event to OnFeintPlayed...
	local Feint = AutoParry.FindSound(HumanoidRootPart, "Feint")
	if Feint then
		table.insert(
			AutoParry.Connections,
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

						AutoParry.OnPlayerFeint(LocalPlayerData, HumanoidRootPart, Player)
					end,

					-- Catch...
					function(Error)
						Pascal:GetLogger():Print("AutoParry.OnPlayerFeint - Caught exception: %s", Error)
					end
				)
			end)
		)

		table.insert(
			AutoParry.Connections,
			Feint.Ended:Connect(function()
				Helper.TryAndCatch(
					-- Try...
					function()
						AutoParry.OnPlayerFeintEnd(Player)
					end,

					-- Catch...
					function(Error)
						Pascal:GetLogger():Print("AutoParry.OnPlayerFeintEnd - Caught exception: %s", Error)
					end
				)
			end)
		)
	end

	-- Connect event to OnAnimationEnded...
	table.insert(
		AutoParry.Connections,
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

					-- Connect event to OnAnimationEnded...
					table.insert(
						AutoParry.Connections,
						AnimationTrack.Stopped:Connect(function()
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

									-- Call OnAnimationEnded...
									AutoParry:OnAnimationEnded(
										EntityData,
										AnimationTrack,
										AnimationTrack.Animation,
										Helper.GetPlayerFromEntity(Entity),
										HumanoidRootPart,
										Humanoid
									)
								end,

								-- Catch...
								function(Error)
									Pascal:GetLogger()
										:Print("AutoParry (AnimationTrack.Stopped) - Caught exception: %s", Error)
								end
							)
						end)
					)
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
