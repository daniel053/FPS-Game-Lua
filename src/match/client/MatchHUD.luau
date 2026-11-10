--!strict
-- HUD da partida (tela T6 do ESTILO, visual final da F7):
--   * topo centro: a minha dupla × a dupla adversária (2 avatares de cada lado, com anel na cor da
--     equipe), vidas de cada dupla em corações e o tempo no meio; selo "VIRADA" na Rodada da Virada;
--     na final, vitórias no lugar das vidas;
--   * no mirante: rodada, etapa e tempo no topo, e o placar resumido com todas as duplas à direita
--     (o placar completo é o Tab, módulo Scoreboard);
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
local Ui = require(Shared.Ui.Ui)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WorldLayout = require(Shared.Match.WorldLayout)

local Captions = require(script.Parent.Parent.Combat.Captions)
local Avatars = require(script.Parent.Parent.Common.Ui.Avatars)
local MatchClient = require(script.Parent.MatchClient)
local SpectateCamera = require(script.Parent.SpectateCamera)

local S = Strings.Match
local HUD = Theme.Hud
local BANNER_SECONDS = 2.6
local SIDE_WIDTH = 150

type Banner = { title: string, subtitle: string?, color: Color3? }
type Side = { root: Frame, avatars: { Avatars.Avatar }, lives: TextLabel }

local MatchHUD = {}

local player = Players.LocalPlayer
local topGui: ScreenGui
local centerGui: ScreenGui
local leftSide: Side
local rightSide: Side
local timerText: TextLabel
local timerPlate: Frame
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
local zoneCaptionRound = 0

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

-- Placar resumido (mirante) ---------------------------------------------------------------------------

local function rebuildScoreboard(snapshot: MatchTypes.Snapshot)
	Ui.clear(scoreList)
	for i, team in snapshot.teams do
		local row = Ui.frame("Row", scoreList)
		row.LayoutOrder = if team.eliminated then 100 + (team.placement or 0) else i
		row.Size = UDim2.new(1, 0, 0, 22)
		local swatch = Ui.frame("Color", row)
		swatch.BackgroundTransparency = if team.eliminated then 0.6 else 0
		swatch.BackgroundColor3 = TeamColors.getColor(team.id)
		swatch.Size = UDim2.fromOffset(12, 12)
		swatch.Position = UDim2.fromOffset(0, 5)
		Ui.corner(swatch, 3)
		local name = Ui.label("Name", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextPrimary, row)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Position = UDim2.fromOffset(18, 0)
		name.Size = UDim2.new(0.55, -18, 1, 0)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Text = memberNames(team)
		name.TextColor3 = if team.eliminated then Theme.Color.TextSecondary else Theme.Color.TextPrimary
		local value = Ui.label("Lives", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextPrimary, row)
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

-- Topo: as duas duplas ----------------------------------------------------------------------------

local function fillSide(side: Side, team: MatchTypes.TeamView?, isFinal: boolean)
	side.root.Visible = team ~= nil
	if team == nil then
		return
	end
	local color = TeamColors.getColor(team.id)
	for i, avatar in side.avatars do
		local member = team.members[i]
		avatar.root.Visible = member ~= nil
		if member then
			Avatars.set(avatar, member.userId, member.name, color, not member.connected)
		end
	end
	side.lives.Text = lives(team, isFinal)
	side.lives.TextColor3 = if isFinal then Theme.Color.TextPrimary else Theme.Color.Hp
end

local function refreshTop(snapshot: MatchTypes.Snapshot)
	local mine = MatchClient.myTeamId()
	local duel = MatchClient.duelOf(mine)
	local inDuel = duel ~= nil and MatchClient.myIsland() ~= nil
	local left, right: MatchTypes.TeamView? = nil, nil
	if duel and inDuel then
		local otherId = if duel.a == mine then duel.b else duel.a
		left, right = MatchClient.team(mine), MatchClient.team(otherId)
	end
	fillSide(leftSide, left, snapshot.isFinal)
	fillSide(rightSide, right, snapshot.isFinal)
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
			if elapsed >= MatchConfig.Zone.StartsAt and zoneCaptionRound ~= snapshot.round then
				zoneCaptionRound = snapshot.round
				Captions.show(Strings.Captions.ZoneClosing)
			end
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
	timerPlate.Visible = timerText.Visible

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

local function makeSide(parent: Instance, isLeft: boolean): Side
	local root = Ui.frame(if isLeft then "Left" else "Right", parent)
	root.AnchorPoint = Vector2.new(if isLeft then 1 else 0, 0)
	root.Position = UDim2.new(0.5, if isLeft then -62 else 62, 0, 4)
	root.Size = UDim2.fromOffset(SIDE_WIDTH, HUD.TopAvatarSize + 4)
	local layout = Ui.list(root, Enum.FillDirection.Horizontal, 6)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = if isLeft then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left

	-- Ordem: [😀😀] ♥♥♥♥♥  tempo  ♥♥♥ [😀😀]
	local avatars = {}
	for i = 1, 2 do
		local avatar = Avatars.new(root, HUD.TopAvatarSize)
		avatar.root.LayoutOrder = if isLeft then i else 10 + i
		table.insert(avatars, avatar)
	end
	local livesLabel = Ui.label("Lives", Theme.Font.Title, HUD.TopHeartSize, Theme.Color.Hp, root)
	livesLabel.AutomaticSize = Enum.AutomaticSize.X
	livesLabel.Size = UDim2.fromOffset(0, HUD.TopAvatarSize)
	livesLabel.LayoutOrder = 5
	Ui.outlineText(livesLabel)
	return { root = root, avatars = avatars, lives = livesLabel }
end

local function build()
	local playerGui = player:WaitForChild("PlayerGui")

	-- Topo: abaixo da barra do Roblox em qualquer aparelho (CoreUISafeInsets, decisão da F1)
	topGui = Ui.screen("MatchTop", 3, Enum.ScreenInsets.CoreUISafeInsets)
	local top = Ui.frame("Top", topGui)
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, Theme.ScreenMargin / 2)
	top.Size = UDim2.fromOffset(2 * SIDE_WIDTH + 124, 76)
	-- Celular pequeno: o topo encolhe para não encostar na engrenagem nem no minimapa
	local fit = Instance.new("UIScale")
	fit.Parent = top
	local function refit()
		local camera = workspace.CurrentCamera
		local width = if camera then camera.ViewportSize.X else 1000
		local free = width - 2 * (Theme.ScreenMargin + Theme.Hud.MinimapSize + Theme.Space.Medium)
		fit.Scale = math.clamp(free / top.Size.X.Offset, 0.7, 1)
	end
	refit()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
	end

	-- Fundo do tempo: placa chanfrada pequena no meio
	local plate = Ui.panel("Plate", top, nil, Theme.Chamfer.Tab)
	timerPlate = plate
	plate.AnchorPoint = Vector2.new(0.5, 0)
	plate.Position = UDim2.fromScale(0.5, 0)
	plate.Size = UDim2.fromOffset(110, 40)

	timerText = Ui.label("Timer", Theme.Font.Number, HUD.TimerTextSize, Theme.Color.TextPrimary, top)
	timerText.AnchorPoint = Vector2.new(0.5, 0)
	timerText.Position = UDim2.fromScale(0.5, 0)
	timerText.Size = UDim2.fromOffset(110, 40)
	timerText.ZIndex = 2

	leftSide = makeSide(top, true)
	rightSide = makeSide(top, false)

	roundText = Ui.label("Round", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextSecondary, top)
	roundText.AnchorPoint = Vector2.new(0.5, 0)
	roundText.Position = UDim2.new(0.5, 0, 0, 42)
	roundText.Size = UDim2.fromOffset(320, 16)
	Ui.outlineText(roundText)

	badge = Ui.label("Virada", Theme.Font.Title, Theme.TextSize.Label, Theme.Color.Overlay, top)
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.new(0.5, 0, 0, 58)
	badge.Size = UDim2.fromOffset(72, 18)
	badge.BackgroundColor3 = Theme.Match.Virada
	badge.BackgroundTransparency = 0
	badge.Text = S.ViradaBadge
	badge.Visible = false
	Ui.corner(badge, 4)

	-- Placar resumido do mirante (direita)
	local content: Frame
	scoreboard, content = Ui.autoPanel("Scoreboard", topGui, 10)
	scoreboard.AnchorPoint = Vector2.new(1, 0)
	scoreboard.Position = UDim2.new(1, -Theme.ScreenMargin, 0, 90)
	scoreboard.Size = UDim2.fromOffset(250, 0)
	scoreboard.Visible = false
	Ui.list(content, Enum.FillDirection.Vertical, 6)
	local title = Ui.label("Title", Theme.Font.Title, Theme.TextSize.Body, Theme.Color.TextPrimary, content)
	title.Size = UDim2.new(1, 0, 0, 18)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = S.Scoreboard
	scoreList = Ui.frame("List", content)
	scoreList.LayoutOrder = 2
	scoreList.Size = UDim2.fromScale(1, 0)
	scoreList.AutomaticSize = Enum.AutomaticSize.Y
	Ui.list(scoreList, Enum.FillDirection.Vertical, 2)

	-- Centro
	centerGui = Ui.screen("MatchCenter", 4, Enum.ScreenInsets.DeviceSafeInsets)
	bannerTitle = Ui.label("Banner", Theme.Font.Title, 34, Theme.Color.TextPrimary, centerGui)
	bannerTitle.AnchorPoint = Vector2.new(0.5, 0.5)
	bannerTitle.Position = UDim2.fromScale(0.5, 0.28)
	bannerTitle.Size = UDim2.new(0.9, 0, 0, 44)
	bannerTitle.TextScaled = true
	bannerTitle.Visible = false
	Ui.outlineText(bannerTitle)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 40
	limit.MinTextSize = Theme.TextSize.Title
	limit.Parent = bannerTitle
	bannerSubtitle =
		Ui.label("BannerSub", Theme.Font.BodyStrong, Theme.TextSize.PrimaryButton, Theme.Color.TextPrimary, centerGui)
	bannerSubtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	bannerSubtitle.Position = UDim2.new(0.5, 0, 0.28, 34)
	bannerSubtitle.Size = UDim2.new(0.9, 0, 0, 24)
	bannerSubtitle.Visible = false
	Ui.outlineText(bannerSubtitle)

	statusText =
		Ui.label("Status", Theme.Font.BodyStrong, Theme.TextSize.PrimaryButton, Theme.Color.TextSecondary, centerGui)
	statusText.AnchorPoint = Vector2.new(0.5, 0)
	statusText.Position = UDim2.fromScale(0.5, 0.6)
	statusText.Size = UDim2.new(0.9, 0, 0, 24)
	Ui.outlineText(statusText)

	afkText = Ui.label("Afk", Theme.Font.BodyStrong, Theme.TextSize.PrimaryButton, Theme.Color.TextPrimary, centerGui)
	afkText.AnchorPoint = Vector2.new(0.5, 0)
	afkText.Position = UDim2.new(0.5, 0, 0.6, 30)
	afkText.Size = UDim2.new(0.9, 0, 0, 24)
	afkText.TextWrapped = true
	afkText.Visible = false
	Ui.outlineText(afkText)

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
