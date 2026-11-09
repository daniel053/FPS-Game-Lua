--!strict
-- Telas de saída da partida, versão SIMPLES (GDD 4.8; visual final na F7):
--   * dupla eliminada: ASSISTIR (fica no mirante) ou NOVA PARTIDA (volta ao lobby; até a F5 o
--     lobby ainda não tem fila);
--   * "Ir para a próxima partida com [nome]?" (SIM / NÃO), quando os dois querem nova partida e no
--     fim da partida para todos com parceiro;
--   * fim da partida: colocação, contagem para voltar ao lobby e NOVA PARTIDA.
-- Fundo escurecido, nunca preto opaco; o mouse fica livre enquanto a tela está aberta (PC).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local MatchTypes = require(Shared.Match.MatchTypes)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)

local InputDevice = require(script.Parent.Parent.Common.InputDevice)
local MatchClient = require(script.Parent.MatchClient)
local MatchUi = require(script.Parent.MatchUi)

local S = Strings.Match
local NOTICE_SECONDS = 4

local EndScreen = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local panel: Frame
local titleText: TextLabel
local bodyText: TextLabel
local buttons: Frame
local primaryButton: TextButton
local secondaryButton: TextButton
local noticeText: TextLabel
local noticeUntil = 0

local onPrimary: (() -> ())? = nil
local onSecondary: (() -> ())? = nil
local countdownEndsAt: number? = nil
local countdownFormat: string? = nil

local function show(title: string, body: string, primary: string?, secondary: string?)
	titleText.Text = title
	bodyText.Text = body
	primaryButton.Visible = primary ~= nil
	primaryButton.Text = primary or ""
	secondaryButton.Visible = secondary ~= nil
	secondaryButton.Text = secondary or ""
	panel.Visible = true
	if InputDevice.get() == "Gamepad" then
		GuiService.SelectedObject = if primary then primaryButton else nil
	end
end

local function hide()
	panel.Visible = false
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
		S.Yes,
		S.No
	)
	local function answer(yes: boolean)
		MatchClient.request("PartnerAnswer", yes)
		local snapshot = MatchClient.get()
		if snapshot and snapshot.phase == "EndScreen" then
			-- No fim: depois de responder, pode sair já ou esperar a contagem
			bodyText.Text = string.format(S.WaitingPartner, data.partnerName)
			primaryButton.Visible = true
			primaryButton.Text = S.NewMatch
			secondaryButton.Visible = false
			onPrimary = function()
				MatchClient.request("NewMatch")
				bodyText.Text = S.GoingToLobby
				primaryButton.Visible = false
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
		primaryButton.Visible = false
	end
end

local function build()
	gui = MatchUi.screen("EndScreen", 30, Enum.ScreenInsets.DeviceSafeInsets)

	panel = MatchUi.panel("Panel", gui)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.55)
	panel.Size = UDim2.fromOffset(460, 230)
	panel.Visible = false
	MatchUi.padding(panel, 18)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(460, 260)
	sizeLimit.Parent = panel

	titleText = MatchUi.label("Title", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, panel)
	titleText.Size = UDim2.new(1, 0, 0, 30)
	bodyText =
		MatchUi.label("Body", Theme.Font.BodyStrong, Theme.TextSize.PrimaryButton, Theme.Color.TextSecondary, panel)
	bodyText.Position = UDim2.fromOffset(0, 40)
	bodyText.Size = UDim2.new(1, 0, 0, 70)
	bodyText.TextWrapped = true

	buttons = MatchUi.frame("Buttons", panel)
	buttons.AnchorPoint = Vector2.new(0.5, 1)
	buttons.Position = UDim2.fromScale(0.5, 1)
	buttons.Size = UDim2.new(1, 0, 0, Theme.PrimaryButtonMinHeight)
	local layout = MatchUi.list(buttons, Enum.FillDirection.Horizontal, Theme.Touch.ButtonGap)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	primaryButton = MatchUi.button("Primary", "", true, buttons)
	primaryButton.LayoutOrder = 1
	primaryButton.Modal = true -- libera o mouse (PC)
	primaryButton.Activated:Connect(function()
		if onPrimary then
			onPrimary()
		end
	end)
	secondaryButton = MatchUi.button("Secondary", "", false, buttons)
	secondaryButton.LayoutOrder = 2
	secondaryButton.Modal = true
	secondaryButton.Activated:Connect(function()
		if onSecondary then
			onSecondary()
		end
	end)

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
			hide()
		end
	end)
	RunService.RenderStepped:Connect(function()
		noticeText.Visible = os.clock() < noticeUntil
		if countdownEndsAt and countdownFormat and panel.Visible and primaryButton.Visible then
			local left = math.max(0, math.ceil(countdownEndsAt - workspace:GetServerTimeNow()))
			titleText.Text = S.EndTitle .. " · " .. string.format(countdownFormat, left)
		end
	end)
end

return EndScreen
