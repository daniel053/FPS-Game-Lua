--!strict
-- HUD da partida PROVISÓRIO (F3; visual final da T6 na F7):
--   * topo centro: a minha dupla × a dupla adversária (cor, nomes), vidas em corações, tempo da
--     etapa; selo "VIRADA" na Rodada da Virada; na final, vitórias no lugar das vidas;
--   * no mirante: rodada, etapa e tempo no topo, e o placar com todas as duplas à direita;
--   * avisos grandes no centro (confrontos, folga, Virada, final, duelo vencido, eliminação, campeã);
--   * linha de estado: esperando jogadores, assistindo o parceiro, fora da zona, ausência.
-- Sem neon; vermelho só para perigo (fora da zona).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local CombatNames = require(Shared.Combat.CombatNames)
local MatchConfig = require(Shared.Config.MatchConfig)
local MatchTypes = require(Shared.Match.MatchTypes)
local Strings = require(Shared.Config.Strings)
local TeamColors = require(Shared.Config.TeamColors)
local TextUtil = require(Shared.TextUtil)
local Theme = require(Shared.Config.Theme)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WorldLayout = require(Shared.Match.WorldLayout)

local MatchClient = require(script.Parent.MatchClient)
local MatchUi = require(Shared.Ui.ProvisionalUi)
local SpectateCamera = require(script.Parent.SpectateCamera)

local S = Strings.Match
local BANNER_SECONDS = 2.6

type Banner = { title: string, subtitle: string?, color: Color3? }

local MatchHUD = {}

local player = Players.LocalPlayer
local topGui: ScreenGui
local centerGui: ScreenGui
local leftTeam: TextLabel
local rightTeam: TextLabel
local leftLives: TextLabel
local rightLives: TextLabel
local timerText: TextLabel
local badge: TextLabel
local roundText: TextLabel
local scoreboard: Frame
local scoreList: Frame
local bannerTitle: TextLabel
local bannerSubtitle: TextLabel
local statusText: TextLabel
local afkText: TextLabel
local bannerQueue: { Banner } = {}
local bannerUntil = 0
local afkSeconds = 0
local afkSetAt = 0

local function lives(team: MatchTypes.TeamView?, isFinal: boolean): string
	if team == nil then
		return ""
	end
	if isFinal then
		return string.format(S.Wins, team.roundWins)
	end
	return string.rep(S.Life, team.lives) .. string.rep(S.LifeLost, math.max(0, MatchConfig.MaxLives - team.lives))
end

local function memberNames(team: MatchTypes.TeamView?): string
	if team == nil then
		return ""
	end
	local names = {}
	for _, m in team.members do
		table.insert(names, m.name)
	end
	return table.concat(names, " · ")
end

local function phaseName(snapshot: MatchTypes.Snapshot): string
	if snapshot.phase == "Prep" or snapshot.phase == "Combat" or snapshot.phase == "Draw" then
		local phase = WeaponConfig.getPhaseForRound(snapshot.round)
		local name = TextUtil.upper(Strings.WeaponPhases[phase.id] or "")
		if snapshot.isFinal then
			return string.format(S.FinalRound, snapshot.round) .. " · " .. name
		end
		return string.format(S.RoundPhase, snapshot.round, name)
	end
	if snapshot.round > 0 then
		return string.format(S.Round, snapshot.round)
	end
	return ""
end

-- Avisos ----------------------------------------------------------------------------------------------

local function pushBanner(banner: Banner)
	table.insert(bannerQueue, banner)
end

local function islandName(island: number?): string
	if island == nil then
		return ""
	end
	return Strings.Maps[WorldLayout.mapId(island)] or ""
end

local function onAnnounce(data: MatchTypes.AnnounceData)
	local mine = MatchClient.myTeamId()
	local kind = data.kind
	if kind == "Matchups" then
		-- Só o confronto da minha dupla vira aviso grande; os outros ficam no placar.
		if data.teamId == mine or data.otherId == mine then
			pushBanner({
				title = string.format(
					S.Matchup,
					MatchClient.teamName(data.teamId),
					MatchClient.teamName(data.otherId),
					islandName(data.island)
				),
			})
		end
	elseif kind == "Bye" then
		if data.teamId == mine then
			pushBanner({ title = S.ByeYou })
		end
	elseif kind == "Virada" then
		pushBanner({ title = S.ViradaTitle, subtitle = S.ViradaSubtitle, color = Theme.Match.Virada })
	elseif kind == "FinalStart" then
		pushBanner({ title = S.FinalTitle, subtitle = S.FinalSubtitle, color = Theme.Match.Final })
	elseif kind == "RoundStart" then
		if MatchClient.myIsland() then
			pushBanner({ title = S.Fight })
		end
	elseif kind == "DuelWon" then
		pushBanner({ title = S.DuelWon, color = Theme.Color.Success })
	elseif kind == "DuelLost" then
		pushBanner({ title = S.DuelLost })
	elseif kind == "DuelTie" then
		pushBanner({ title = S.DuelTie })
	elseif kind == "TeamEliminated" then
		pushBanner({ title = string.format(S.TeamEliminated, MatchClient.teamName(data.teamId)) })
	elseif kind == "Champion" then
		local title = if data.teamId == mine
			then S.YouAreChampion
			else string.format(S.ChampionTitle, TextUtil.upper(MatchClient.teamName(data.teamId)))
		pushBanner({ title = title, color = Theme.Color.Coin })
	elseif kind == "PartnerLeft" then
		pushBanner({ title = S.PartnerLeft })
	end
end

-- Placar (mirante) ------------------------------------------------------------------------------------

local function rebuildScoreboard(snapshot: MatchTypes.Snapshot)
	for _, child in scoreList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, team in snapshot.teams do
		local row = MatchUi.frame("Row", scoreList)
		row.LayoutOrder = if team.eliminated then 100 + (team.placement or 0) else i
		row.Size = UDim2.new(1, 0, 0, 22)
		local swatch = MatchUi.frame("Color", row)
		swatch.BackgroundTransparency = if team.eliminated then 0.6 else 0
		swatch.BackgroundColor3 = TeamColors.getColor(team.id)
		swatch.Size = UDim2.fromOffset(12, 12)
		swatch.Position = UDim2.fromOffset(0, 5)
		MatchUi.corner(swatch, 3)
		local name = MatchUi.label("Name", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextPrimary, row)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Position = UDim2.fromOffset(18, 0)
		name.Size = UDim2.new(0.55, -18, 1, 0)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Text = memberNames(team)
		name.TextColor3 = if team.eliminated then Theme.Color.TextSecondary else Theme.Color.TextPrimary
		local value = MatchUi.label("Lives", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextPrimary, row)
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.fromScale(1, 0)
		value.Size = UDim2.fromScale(0.45, 1)
		if team.eliminated then
			value.Text = string.format(S.Placement, team.placement or 0)
			value.TextColor3 = Theme.Color.TextSecondary
		else
			value.Text = lives(team, snapshot.isFinal)
			value.TextColor3 = if team.id == snapshot.bye then Theme.Color.TextSecondary else Theme.Color.Hp
		end
	end
end

local function refreshTop(snapshot: MatchTypes.Snapshot)
	local mine = MatchClient.myTeamId()
	local duel = MatchClient.duelOf(mine)
	local inDuel = duel ~= nil and MatchClient.myIsland() ~= nil
	local left, right: MatchTypes.TeamView? = nil, nil
	if duel then
		local otherId = if duel.a == mine then duel.b else duel.a
		left, right = MatchClient.team(mine), MatchClient.team(otherId)
	end
	for _, l in { leftTeam, rightTeam, leftLives, rightLives } do
		l.Visible = inDuel
	end
	if inDuel and left and right then
		leftTeam.Text = memberNames(left)
		leftTeam.TextColor3 = TeamColors.getColor(left.id)
		rightTeam.Text = memberNames(right)
		rightTeam.TextColor3 = TeamColors.getColor(right.id)
		leftLives.Text = lives(left, snapshot.isFinal)
		rightLives.Text = lives(right, snapshot.isFinal)
	end
	roundText.Text = phaseName(snapshot)
	badge.Visible = snapshot.isVirada
		and (snapshot.phase == "Prep" or snapshot.phase == "Combat" or snapshot.phase == "Draw")
	scoreboard.Visible = MatchClient.isOnMirante() and #snapshot.teams > 0
	rebuildScoreboard(snapshot)
end

-- Estado a cada quadro ----------------------------------------------------------------------------------

local function statusLine(snapshot: MatchTypes.Snapshot?): (string, Color3)
	local secondary = Theme.Color.TextSecondary
	if snapshot == nil then
		return "", secondary
	end
	local now = workspace:GetServerTimeNow()
	if snapshot.phase == "Receiving" then
		if snapshot.endsAt then
			return string.format(S.StartsIn, math.max(0, math.ceil(snapshot.endsAt - now))), Theme.Color.TextPrimary
		end
		return string.format(S.Waiting, snapshot.waiting, snapshot.minPlayers), secondary
	elseif snapshot.phase == "Forming" then
		return S.Forming, secondary
	end
	local spectating = SpectateCamera.getTargetName()
	if spectating then
		return string.format(S.Spectating, spectating), Theme.Color.TextPrimary
	end
	if snapshot.phase == "Combat" and snapshot.combatStartedAt then
		local island = MatchClient.myIsland()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if island and root and root:IsA("BasePart") then
			local elapsed = now - snapshot.combatStartedAt
			local center = WorldLayout.islandCenter(island)
			local flat = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
			if flat.Magnitude > WorldLayout.zoneRadius(elapsed) then
				return S.OutsideZone, Theme.Color.Danger
			elseif elapsed >= MatchConfig.Zone.StartsAt then
				return S.ZoneClosing, secondary
			end
		end
	end
	if MatchClient.isOnMirante() and snapshot.phase ~= "Champion" and snapshot.phase ~= "EndScreen" then
		return TextUtil.upper(S.OnMirante), secondary
	end
	return "", secondary
end

local function update()
	local snapshot = MatchClient.get()
	local now = workspace:GetServerTimeNow()
	if snapshot and snapshot.endsAt then
		local left = math.max(0, math.ceil(snapshot.endsAt - now))
		timerText.Text = string.format("%d:%02d", left // 60, left % 60)
		timerText.Visible = true
	else
		timerText.Visible = false
	end

	local text, color = statusLine(snapshot)
	statusText.Text = text
	statusText.TextColor3 = color

	if afkSeconds > 0 then
		local left = math.max(0, math.ceil(afkSeconds - (os.clock() - afkSetAt)))
		afkText.Text = string.format(S.AfkWarning, left)
		afkText.Visible = true
	else
		afkText.Visible = false
	end

	local clock = os.clock()
	if clock >= bannerUntil then
		local banner = table.remove(bannerQueue, 1)
		if banner then
			bannerTitle.Text = banner.title
			bannerTitle.TextColor3 = banner.color or Theme.Color.TextPrimary
			bannerSubtitle.Text = banner.subtitle or ""
			bannerUntil = clock + BANNER_SECONDS
		end
	end
	local showing = clock < bannerUntil
	bannerTitle.Visible = showing
	bannerSubtitle.Visible = showing and bannerSubtitle.Text ~= ""
end

-- Montagem --------------------------------------------------------------------------------------------

local function build()
	local playerGui = player:WaitForChild("PlayerGui")

	-- Topo: abaixo da barra do Roblox em qualquer aparelho (CoreUISafeInsets, decisão da F1)
	topGui = MatchUi.screen("MatchTop", 3, Enum.ScreenInsets.CoreUISafeInsets)
	local top = MatchUi.frame("Top", topGui)
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, Theme.ScreenMargin / 2)
	top.Size = UDim2.fromOffset(560, 74)

	timerText = MatchUi.label("Timer", Theme.Font.Number, 30, Theme.Color.TextPrimary, top)
	timerText.AnchorPoint = Vector2.new(0.5, 0)
	timerText.Position = UDim2.fromScale(0.5, 0)
	timerText.Size = UDim2.fromOffset(100, 34)
	MatchUi.outlineText(timerText)

	roundText = MatchUi.label("Round", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextSecondary, top)
	roundText.AnchorPoint = Vector2.new(0.5, 0)
	roundText.Position = UDim2.new(0.5, 0, 0, 34)
	roundText.Size = UDim2.fromOffset(320, 16)
	MatchUi.outlineText(roundText)

	badge = MatchUi.label("Virada", Theme.Font.Title, Theme.TextSize.Label, Theme.Color.Overlay, top)
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.new(0.5, 0, 0, 52)
	badge.Size = UDim2.fromOffset(72, 18)
	badge.BackgroundColor3 = Theme.Match.Virada
	badge.BackgroundTransparency = 0
	badge.Text = S.ViradaBadge
	badge.Visible = false
	MatchUi.corner(badge, 4)

	local function side(name: string, anchorX: number, x: number, align: Enum.TextXAlignment): (TextLabel, TextLabel)
		local teamLabel = MatchUi.label(name, Theme.Font.Title, Theme.TextSize.Body, Theme.Color.TextPrimary, top)
		teamLabel.AnchorPoint = Vector2.new(anchorX, 0)
		teamLabel.Position = UDim2.new(x, 0, 0, 2)
		teamLabel.Size = UDim2.fromOffset(200, 18)
		teamLabel.TextXAlignment = align
		teamLabel.TextTruncate = Enum.TextTruncate.AtEnd
		MatchUi.outlineText(teamLabel)
		local livesLabel = MatchUi.label(name .. "Lives", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.Hp, top)
		livesLabel.AnchorPoint = Vector2.new(anchorX, 0)
		livesLabel.Position = UDim2.new(x, 0, 0, 20)
		livesLabel.Size = UDim2.fromOffset(200, 26)
		livesLabel.TextXAlignment = align
		MatchUi.outlineText(livesLabel)
		return teamLabel, livesLabel
	end
	leftTeam, leftLives = side("Left", 0, 0, Enum.TextXAlignment.Left)
	rightTeam, rightLives = side("Right", 1, 1, Enum.TextXAlignment.Right)

	-- Placar do mirante (direita)
	scoreboard = MatchUi.panel("Scoreboard", topGui)
	scoreboard.AnchorPoint = Vector2.new(1, 0)
	scoreboard.Position = UDim2.new(1, -Theme.ScreenMargin, 0, 90)
	scoreboard.Size = UDim2.fromOffset(250, 0)
	scoreboard.AutomaticSize = Enum.AutomaticSize.Y
	scoreboard.Visible = false
	MatchUi.padding(scoreboard, 10)
	MatchUi.list(scoreboard, Enum.FillDirection.Vertical, 6)
	local title = MatchUi.label("Title", Theme.Font.Title, Theme.TextSize.Body, Theme.Color.TextPrimary, scoreboard)
	title.Size = UDim2.new(1, 0, 0, 18)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = S.Scoreboard
	scoreList = MatchUi.frame("List", scoreboard)
	scoreList.LayoutOrder = 2
	scoreList.Size = UDim2.fromScale(1, 0)
	scoreList.AutomaticSize = Enum.AutomaticSize.Y
	MatchUi.list(scoreList, Enum.FillDirection.Vertical, 2)

	-- Centro
	centerGui = MatchUi.screen("MatchCenter", 4, Enum.ScreenInsets.DeviceSafeInsets)
	bannerTitle = MatchUi.label("Banner", Theme.Font.Title, 34, Theme.Color.TextPrimary, centerGui)
	bannerTitle.AnchorPoint = Vector2.new(0.5, 0.5)
	bannerTitle.Position = UDim2.fromScale(0.5, 0.28)
	bannerTitle.Size = UDim2.new(0.9, 0, 0, 44)
	bannerTitle.TextScaled = true
	bannerTitle.Visible = false
	MatchUi.outlineText(bannerTitle)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 40
	limit.MinTextSize = Theme.TextSize.Title
	limit.Parent = bannerTitle
	bannerSubtitle = MatchUi.label(
		"BannerSub",
		Theme.Font.BodyStrong,
		Theme.TextSize.PrimaryButton,
		Theme.Color.TextPrimary,
		centerGui
	)
	bannerSubtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	bannerSubtitle.Position = UDim2.new(0.5, 0, 0.28, 34)
	bannerSubtitle.Size = UDim2.new(0.9, 0, 0, 24)
	bannerSubtitle.Visible = false
	MatchUi.outlineText(bannerSubtitle)

	statusText = MatchUi.label(
		"Status",
		Theme.Font.BodyStrong,
		Theme.TextSize.PrimaryButton,
		Theme.Color.TextSecondary,
		centerGui
	)
	statusText.AnchorPoint = Vector2.new(0.5, 0)
	statusText.Position = UDim2.fromScale(0.5, 0.6)
	statusText.Size = UDim2.new(0.9, 0, 0, 24)
	MatchUi.outlineText(statusText)

	afkText =
		MatchUi.label("Afk", Theme.Font.BodyStrong, Theme.TextSize.PrimaryButton, Theme.Color.TextPrimary, centerGui)
	afkText.AnchorPoint = Vector2.new(0.5, 0)
	afkText.Position = UDim2.new(0.5, 0, 0.6, 30)
	afkText.Size = UDim2.new(0.9, 0, 0, 24)
	afkText.TextWrapped = true
	afkText.Visible = false
	MatchUi.outlineText(afkText)

	topGui.Parent = playerGui
	centerGui.Parent = playerGui
end

function MatchHUD.Start()
	if not MatchClient.isEnabled() then
		return
	end
	build()
	MatchClient.onChanged(refreshTop)
	MatchClient.onEvent("Announce", onAnnounce)
	MatchClient.onEvent("AfkWarning", function(data: { seconds: number })
		afkSeconds = data.seconds
		afkSetAt = os.clock()
	end)
	local function refreshLater()
		local snapshot = MatchClient.get()
		if snapshot then
			refreshTop(snapshot)
		end
	end
	player:GetAttributeChangedSignal(MatchTypes.Attr.Location):Connect(refreshLater)
	player:GetAttributeChangedSignal(CombatNames.Attr.TeamId):Connect(refreshLater)
	RunService.RenderStepped:Connect(update)
end

return MatchHUD
