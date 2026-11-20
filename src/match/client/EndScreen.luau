--!strict
-- Telas de saída da partida (GDD 4.8), no visual final da F7 (painel chanfrado, botões do Widgets):
--   * dupla eliminada: ASSISTIR (fica no mirante) ou NOVA PARTIDA (volta ao lobby e entra direto
--     na fila, F5);
--   * "Ir para a próxima partida com [nome]?" (SIM / NÃO), quando os dois querem nova partida e no
--     fim da partida para todos com parceiro;
--   * fim da partida: colocação, contagem para voltar ao lobby e NOVA PARTIDA. Quem disse "sim" dos
--     dois lados volta como dupla fixa e entra direto na fila. No fim, o "sim" se chama
--     "JOGAR DE NOVO JUNTOS" (F8);
--   * linha social (F8, GDD 12.4): ADICIONAR AMIGO (pedido nativo do Roblox), ELOGIAR o parceiro e
--     DENUNCIAR (ReportPanel).
--   * recompensas (F9): moedas (com o detalhe) e PE da partida, com o elo depois, quando são creditadas
--     (ao cair ou no fim da partida).
-- Fundo escurecido, nunca preto opaco; o mouse fica livre enquanto a tela está aberta (PC).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage.Shared
local MatchTypes = require(Shared.Match.MatchTypes)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)

local InputDevice = require(script.Parent.Parent.Common.InputDevice)
local Widgets = require(script.Parent.Parent.Common.Ui.Widgets)
local RankBadge = require(script.Parent.Parent.Common.Ui.RankBadge)
local MatchClient = require(script.Parent.MatchClient)
local ReportPanel = require(script.Parent.ReportPanel)
local SocialClient = require(script.Parent.SocialClient)
local MatchUi = require(Shared.Ui.Ui)
local SocialRules = require(Shared.Social.SocialRules)

local S = Strings.Match
local SS = Strings.Social
local NOTICE_SECONDS = 4

local EndScreen = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local panel: Frame
local titleText: TextLabel
local bodyText: TextLabel
local buttons: Frame
local primaryButton: Widgets.Button
local secondaryButton: Widgets.Button
local noticeText: TextLabel
local noticeUntil = 0
-- Recompensas da partida (F9): chegam pelo evento "Rewards" quando são creditadas
local rewardsText: TextLabel
local rewards: MatchTypes.RewardsData? = nil

local onPrimary: (() -> ())? = nil
local onSecondary: (() -> ())? = nil
local countdownEndsAt: number? = nil
local countdownFormat: string? = nil

-- Linha social (F8)
local socialRow: Frame
local friendButton: Widgets.Button
local praiseButton: Widgets.Button
local reportButton: Widgets.Button
local socialShown = false
local friendState: { [number]: "checking" | "no" | "friends" | "sent" } = {}

local function phaseNow(): string?
	local snapshot = MatchClient.get()
	return if snapshot then snapshot.phase else nil
end

local function show(title: string, body: string, primary: string?, secondary: string?)
	titleText.Text = title
	bodyText.Text = body
	primaryButton.root.Visible = primary ~= nil
	primaryButton.setText(primary or "")
	secondaryButton.root.Visible = secondary ~= nil
	secondaryButton.setText(secondary or "")
	if not panel.Visible then
		Widgets.popIn(panel)
	end
	panel.Visible = true
	if InputDevice.get() == "Gamepad" then
		GuiService.SelectedObject = if primary then primaryButton.root else nil
	end
end

-- Linha social (F8, GDD 12.4): ADICIONAR AMIGO e ELOGIAR o parceiro, DENUNCIAR sempre.
local function refreshSocial()
	local partner = MatchClient.partnerPlayer()
	socialRow.Visible = panel.Visible and socialShown
	friendButton.root.Visible = partner ~= nil
	praiseButton.root.Visible = partner ~= nil and SocialRules.praiseKey(phaseNow(), 0) ~= nil
	if partner == nil then
		return
	end
	if friendState[partner.UserId] == "sent" then
		friendButton.setText(SS.FriendSent)
		friendButton.setEnabled(false)
	elseif friendState[partner.UserId] == "friends" then
		friendButton.setText(SS.AlreadyFriends)
		friendButton.setEnabled(false)
	else
		friendButton.setText(SS.AddFriend)
		friendButton.setEnabled(true)
		if friendState[partner.UserId] == nil then
			friendState[partner.UserId] = "checking"
			local userId = partner.UserId
			task.spawn(function()
				local ok, isFriend = pcall(function()
					return player:IsFriendsWith(userId)
				end)
				friendState[userId] = if ok and isFriend then "friends" else "no"
				refreshSocial()
			end)
		end
	end
	local canPraise = SocialClient.canPraise()
	praiseButton.setText(if canPraise then SS.PraiseShort else SS.PraiseDone)
	praiseButton.setEnabled(canPraise)
end

-- Moedas e PE da partida, em duas linhas: total e elo; o detalhe das moedas embaixo, menor.
local function rewardsLines(data: MatchTypes.RewardsData): string
	local R = Strings.Rewards
	local coinHex = Theme.Color.Coin:ToHex()
	local first = `<font color="#{coinHex}">{string.format(R.Coins, Strings.Ui.Coin, data.coins)}</font>`
	if not data.ranked then
		first ..= "   " .. (if data.casual then R.Casual else R.Private) -- [BOTS] casual = partida com bots
	else
		local delta = data.rankDelta
		local deltaText = if delta > 0
			then string.format(R.RankUp, delta)
			elseif delta < 0 then string.format(R.RankDown, -delta)
			else R.RankSame
		local color = if delta > 0 then Theme.RankUp else Theme.RankDown
		first ..= `   <font color="#{color:ToHex()}">{deltaText}</font> · {RankBadge.rich(data.rankTier)}`
		if data.rankProtected then
			first ..= ` ({R.Protected})`
		elseif data.rankDoubled then
			first ..= ` ({R.Doubled})`
		end
		if data.rankTier ~= data.rankTierBefore and data.rankTierBefore ~= "" then
			local tierFmt = if delta > 0 then R.TierUp else R.TierDown
			first ..= "\n" .. string.format(tierFmt, RankBadge.rich(data.rankTier))
		end
	end
	local parts: { string } = {}
	local breakdown = data.coinsBreakdown :: { [string]: number }
	for _, key in R.PartsOrder do
		local value = breakdown[key]
		if value and value > 0 then
			table.insert(parts, string.format(R.Parts[key], value))
		end
	end
	local small = `<font size="{Theme.TextSize.Label}">{table.concat(parts, " · ")}</font>`
	return first .. "\n" .. small
end

local function refreshRewards()
	local data = rewards
	rewardsText.Visible = panel.Visible and data ~= nil
	if data then
		rewardsText.Text = rewardsLines(data)
	end
end

local function setSocial(shown: boolean)
	socialShown = shown
	refreshSocial()
	refreshRewards()
end

local function hide()
	panel.Visible = false
	setSocial(false)
	onPrimary, onSecondary = nil, nil
	countdownEndsAt = nil
	countdownFormat = nil
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
end

local function notice(text: string)
	noticeText.Text = text
	noticeUntil = os.clock() + NOTICE_SECONDS
end

local function showEliminated()
	show(S.EliminatedTitle, "", S.Watch, S.NewMatch)
	setSocial(true)
	onPrimary = function()
		MatchClient.request("Watch")
		hide()
	end
	onSecondary = function()
		MatchClient.request("NewMatch")
		show(S.EliminatedTitle, S.GoingToLobby, nil, nil)
	end
end

local function showPartnerQuestion(data: { partnerName: string })
	local previousTitle = titleText.Text
	show(
		if panel.Visible and previousTitle ~= "" then previousTitle else S.EndTitle,
		string.format(S.PartnerQuestion, data.partnerName),
		-- No fim da partida, o "sim" é o botão "Jogar de novo juntos" (GDD 12.4)
		if phaseNow() == "EndScreen" then SS.PlayAgainTogether else S.Yes,
		S.No
	)
	local function answer(yes: boolean)
		MatchClient.request("PartnerAnswer", yes)
		local snapshot = MatchClient.get()
		if snapshot and snapshot.phase == "EndScreen" then
			-- No fim: depois de responder, pode sair já ou esperar a contagem
			bodyText.Text = string.format(S.WaitingPartner, data.partnerName)
			primaryButton.root.Visible = true
			primaryButton.setText(S.NewMatch)
			secondaryButton.root.Visible = false
			onPrimary = function()
				MatchClient.request("NewMatch")
				bodyText.Text = S.GoingToLobby
				primaryButton.root.Visible = false
			end
		else
			show(titleText.Text, string.format(S.WaitingPartner, data.partnerName), nil, nil)
		end
	end
	onPrimary = function()
		answer(true)
	end
	onSecondary = function()
		answer(false)
	end
end

local function showEnd(data: MatchTypes.EndScreenData)
	local body = if data.placement then string.format(S.EndPlacement, data.placement) else ""
	show(S.EndTitle, body, S.NewMatch, nil)
	countdownEndsAt = data.endsAt
	countdownFormat = S.BackToLobbyIn
	onPrimary = function()
		MatchClient.request("NewMatch")
		bodyText.Text = S.GoingToLobby
		primaryButton.root.Visible = false
	end
	setSocial(true)
end

local function buildSocial(content: Frame)
	socialRow = MatchUi.frame("Social", content)
	socialRow.AnchorPoint = Vector2.new(0.5, 1)
	socialRow.Position = UDim2.new(0.5, 0, 1, -(Theme.PrimaryButtonMinHeight + Theme.Space.Small))
	socialRow.Size = UDim2.new(1, 0, 0, Theme.Touch.MinTarget)
	socialRow.Visible = false
	local layout = MatchUi.list(socialRow, Enum.FillDirection.Horizontal, Theme.Touch.ButtonGap)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local function small(text: string, order: number): Widgets.Button
		local b = Widgets.button(socialRow, text, "secondary", {
			size = UDim2.new(1 / 3, -8, 1, 0),
			textSize = Theme.TextSize.Label,
			arrow = false,
			order = order,
			modal = true,
		})
		return b
	end
	friendButton = small(SS.AddFriend, 1)
	friendButton.onClick(function()
		local partner = MatchClient.partnerPlayer()
		if partner == nil then
			return
		end
		local ok = pcall(function()
			StarterGui:SetCore("PromptSendFriendRequest", partner)
		end)
		if ok then
			friendState[partner.UserId] = "sent"
		end
		refreshSocial()
	end)
	praiseButton = small(SS.PraiseShort, 2)
	praiseButton.onClick(function()
		SocialClient.praise()
		refreshSocial()
	end)
	reportButton = small(SS.Report, 3)
	reportButton.onClick(ReportPanel.open)
	SocialClient.onPraiseChanged(refreshSocial)
end

local function build()
	gui = MatchUi.screen("EndScreen", 30, Enum.ScreenInsets.DeviceSafeInsets)

	local content: Frame
	panel, content = MatchUi.panel("Panel", gui, 18)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.55)
	panel.Size = UDim2.fromOffset(480, 300)
	panel.Visible = false
	MatchUi.sizeLimit(panel, nil, Vector2.new(480, 320))

	titleText = MatchUi.label("Title", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, content)
	titleText.Size = UDim2.new(1, 0, 0, 30)
	bodyText =
		MatchUi.label("Body", Theme.Font.BodyStrong, Theme.TextSize.PrimaryButton, Theme.Color.TextSecondary, content)
	bodyText.Position = UDim2.fromOffset(0, 40)
	bodyText.Size = UDim2.new(1, 0, 0, 44)
	bodyText.TextWrapped = true

	-- Moedas e PE da partida (F9)
	rewardsText = MatchUi.label("Rewards", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, content)
	rewardsText.Position = UDim2.fromOffset(0, 86)
	rewardsText.Size = UDim2.new(1, 0, 0, 62)
	rewardsText.TextWrapped = true
	rewardsText.RichText = true
	rewardsText.Visible = false

	buttons = MatchUi.frame("Buttons", content)
	buttons.AnchorPoint = Vector2.new(0.5, 1)
	buttons.Position = UDim2.fromScale(0.5, 1)
	buttons.Size = UDim2.new(1, 0, 0, Theme.PrimaryButtonMinHeight)
	local layout = MatchUi.list(buttons, Enum.FillDirection.Horizontal, Theme.Touch.ButtonGap)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	primaryButton = Widgets.button(buttons, "", "primary", {
		size = UDim2.new(0.5, -6, 1, 0),
		order = 1,
		modal = true, -- libera o mouse (PC)
	})
	primaryButton.onClick(function()
		if onPrimary then
			onPrimary()
		end
	end)
	secondaryButton = Widgets.button(buttons, "", "secondary", {
		size = UDim2.new(0.5, -6, 1, 0),
		order = 2,
		modal = true,
	})
	secondaryButton.onClick(function()
		if onSecondary then
			onSecondary()
		end
	end)
	buildSocial(content)

	noticeText = MatchUi.label("Notice", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextPrimary, gui)
	noticeText.AnchorPoint = Vector2.new(0.5, 1)
	noticeText.Position = UDim2.new(0.5, 0, 1, -150)
	noticeText.Size = UDim2.new(0.9, 0, 0, 22)
	noticeText.TextWrapped = true
	noticeText.Visible = false
	MatchUi.outlineText(noticeText)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function EndScreen.Start()
	if not MatchClient.isEnabled() then
		return
	end
	build()
	MatchClient.onEvent("Eliminated", showEliminated)
	MatchClient.onEvent("PartnerQuestion", showPartnerQuestion)
	MatchClient.onEvent("EndScreen", showEnd)
	MatchClient.onEvent("Rewards", function(data: MatchTypes.RewardsData)
		rewards = data
		refreshRewards()
	end)
	MatchClient.onEvent("Notice", function(data: { key: string })
		if data.key == "GoingToLobby" then
			notice(S.GoingToLobby)
			return
		end
		local text = S.Notices[data.key]
		if text then
			notice(text)
		end
		if data.key == "TeleportStudio" or data.key == "TeleportFailed" then
			hide()
		end
	end)
	MatchClient.onChanged(function(snapshot: MatchTypes.Snapshot)
		-- Nova partida começando (no Studio, depois do fim): fecha tudo
		if snapshot.phase == "Receiving" or snapshot.phase == "Forming" then
			rewards = nil
			hide()
		end
	end)
	RunService.RenderStepped:Connect(function()
		noticeText.Visible = os.clock() < noticeUntil
		if countdownEndsAt and countdownFormat and panel.Visible and primaryButton.root.Visible then
			local left = math.max(0, math.ceil(countdownEndsAt - workspace:GetServerTimeNow()))
			titleText.Text = S.EndTitle .. " · " .. string.format(countdownFormat, left)
		end
	end)
end

return EndScreen
