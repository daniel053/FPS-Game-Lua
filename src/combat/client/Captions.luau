--!strict
-- Legendas de avisos sonoros importantes (ESTILO 5, F7): uma linha curta embaixo, acima das cartas,
-- que some sozinha. Ex.: "Inimigo usou Tremor", "Parceiro usou Nuvem".
-- Cartas: só quem está na mesma ilha (ou o parceiro, em qualquer lugar). Outros módulos chamam show().

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local CardTypes = require(Shared.Cards.CardTypes)
local CombatNames = require(Shared.Combat.CombatNames)
local MatchTypes = require(Shared.Match.MatchTypes)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local Ui = require(Shared.Ui.Ui)
local UiConfig = require(Shared.Config.UiConfig)

local C = Strings.Captions
local CFG = UiConfig.Captions

type Line = { label: TextLabel, untilT: number }

local Captions = {}

local player = Players.LocalPlayer
local list: Frame? = nil
local lines: { Line } = {}
local order = 0

function Captions.show(text: string, color: Color3?)
	local parent = list
	if parent == nil then
		return
	end
	order += 1
	local label =
		Ui.label("Caption", Theme.Font.BodyStrong, Theme.TextSize.Body, color or Theme.Color.TextPrimary, parent)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 24)
	label.BackgroundColor3 = Theme.Color.PanelBase
	label.BackgroundTransparency = 0.25
	label.LayoutOrder = order
	label.Text = text
	Ui.corner(label, 4)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = label
	table.insert(lines, { label = label, untilT = os.clock() + CFG.Seconds })
	while #lines > CFG.MaxLines do
		local oldest = table.remove(lines, 1)
		if oldest then
			oldest.label:Destroy()
		end
	end
end

local function cardName(id: string): string
	local entry = Strings.Cards[id]
	return if entry then entry.name else id
end

local function myIsland(): any
	local character = player.Character
	return character and character:GetAttribute(MatchTypes.Attr.Island)
end

local function onCardFx(kind: string, data: any)
	local caster = if typeof(data) == "table" then data.caster else nil
	if typeof(caster) ~= "Instance" or caster == player then
		return
	end
	-- Jogador, ou o corpo de um bot de preenchimento [BOTS] (equipe e ilha nos atributos do corpo)
	local casterCharacter: Instance? = nil
	if caster:IsA("Player") then
		casterCharacter = caster.Character
	elseif caster:IsA("Model") then
		casterCharacter = caster
	else
		return
	end
	local id = if kind == "NuvemThrow"
		then "card_nuvem"
		elseif kind == "TremorWave" then "card_tremor"
		elseif kind == "RenascerReturn" then "card_renascer"
		else nil
	if id == nil then
		return
	end
	local myTeam = player:GetAttribute(CombatNames.Attr.TeamId)
	local partner = myTeam ~= nil and caster:GetAttribute(CombatNames.Attr.TeamId) == myTeam
	if partner then
		Captions.show(string.format(C.AllyCard, cardName(id)), Theme.Marker.AllyBar)
		return
	end
	local island = myIsland()
	if island ~= nil and casterCharacter and casterCharacter:GetAttribute(MatchTypes.Attr.Island) == island then
		Captions.show(string.format(C.EnemyCard, cardName(id)), Theme.Color.Danger)
	end
end

function Captions.Start()
	local gui = Ui.screen("Captions", 7, Enum.ScreenInsets.DeviceSafeInsets)
	local frame = Ui.frame("Lines", gui)
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -150)
	frame.Size = UDim2.fromOffset(500, 90)
	list = frame
	local layout = Ui.list(frame, Enum.FillDirection.Vertical, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	gui.Parent = player:WaitForChild("PlayerGui")

	Remotes.event("CardFx").OnClientEvent:Connect(function(kind: string, data: CardTypes.NuvemThrowData | any)
		onCardFx(kind, data)
	end)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for i = #lines, 1, -1 do
			if now >= lines[i].untilT then
				lines[i].label:Destroy()
				table.remove(lines, i)
			end
		end
	end)
end

return Captions
