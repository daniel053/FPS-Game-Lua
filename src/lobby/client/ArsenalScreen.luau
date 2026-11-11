--!strict
-- Arsenal (ESTILO T5, F7): ver todas as armas e escolher a SKIN de cada uma. Não escolhe a arma da
-- partida (isso é no modal de preparação). A loja e o catálogo de skins são da F9: por enquanto cada
-- arma só tem a skin "Padrão", já equipada.
--   * Abas: Todas, Primária, Secundária, Corpo a corpo, Habilidade [DECIDIDO].
--   * Grade de cartões (a arma em 3D e o nome); em "Todas", agrupada por categoria.
--   * Painel de detalhe: a arma em 3D girando devagar, nome, uma frase, fila de skins e EQUIPAR.
--   * Celular: o painel de detalhe abre por cima da grade, na metade direita, e fecha no "‹".
--   * Aba Habilidade: as cartas e as skins de efeito ficam na tela de Cartas (botão VER CARTAS).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Strings = require(Shared.Config.Strings)
local TextUtil = require(Shared.TextUtil)
local Theme = require(Shared.Config.Theme)
local Ui = require(Shared.Ui.Ui)
local WeaponConfig = require(Shared.Config.WeaponConfig)

local InputDevice = require(script.Parent.Parent.Common.InputDevice)
local WeaponPreview = require(script.Parent.Parent.Common.Ui.WeaponPreview)
local Widgets = require(script.Parent.Parent.Common.Ui.Widgets)
local CardsScreen = require(script.Parent.CardsScreen)

local A = Strings.Arsenal
local U = Strings.Ui
local CARD_SIZE = Vector2.new(112, 88)
local CATEGORY_ORDER = { "Pistol", "SMG", "Shotgun", "LightRifle", "Rifle", "Sniper", "MachineGun" }

local ArsenalScreen = {}

local player = Players.LocalPlayer
local modal: Widgets.Modal
local tabs: Widgets.Tabs
local gridArea: ScrollingFrame
local abilityArea: Frame
local detail: Frame
local detailPreview: WeaponPreview.Preview
local detailName: TextLabel
local detailCategory: TextLabel
local detailDesc: TextLabel
local equipButton: Widgets.Button
local cards: { [string]: Widgets.ItemCard } = {}
local selected: string? = nil
local currentTab = "All"

local function categoryName(id: string): string
	if id == WeaponConfig.Melee.id then
		return A.Tabs.Melee
	end
	local def = WeaponConfig.get(id)
	return if def then (Strings.WeaponCategories[def.category] or def.category) else ""
end

local function isTouch(): boolean
	return InputDevice.get() == "Touch"
end

local function showDetail(id: string?)
	selected = id
	for weaponId, card in cards do
		card.setSelected(weaponId == id)
	end
	detail.Visible = id ~= nil and (not isTouch() or currentTab ~= "Ability")
	if id == nil then
		return
	end
	detailPreview.set(id)
	detailName.Text = TextUtil.upper(Strings.Weapons[id] or id)
	detailCategory.Text = TextUtil.upper(categoryName(id))
	detailDesc.Text = A.Descriptions[id] or ""
	-- Só existe a skin Padrão, já equipada (catálogo e loja na F9)
	equipButton.setText(A.Equipped .. " " .. U.Check)
	equipButton.setEnabled(false)
end

-- IDs da aba: secundária = pistolas; primária = o resto das armas de fogo; corpo a corpo = Bastão.
local function idsFor(tab: string): { { title: string?, ids: { string } } }
	local byCategory: { [string]: { string } } = {}
	for _, def in WeaponConfig.Weapons do
		local list = byCategory[def.category]
		if list == nil then
			list = {}
			byCategory[def.category] = list
		end
		table.insert(list, def.id)
	end
	local groups = {}
	if tab == "All" or tab == "Primary" or tab == "Secondary" then
		for _, category in CATEGORY_ORDER do
			local isSecondary = category == "Pistol"
			local wanted = tab == "All" or (tab == "Secondary") == isSecondary
			local list = byCategory[category]
			if wanted and list then
				table.insert(groups, { title = Strings.WeaponCategories[category] or category, ids = list })
			end
		end
	end
	if tab == "All" or tab == "Melee" then
		table.insert(groups, { title = A.Tabs.Melee, ids = { WeaponConfig.Melee.id } })
	end
	return groups
end

local function rebuild()
	Ui.clear(gridArea)
	table.clear(cards)
	local ability = currentTab == "Ability"
	abilityArea.Visible = ability
	gridArea.Visible = not ability
	if ability then
		detail.Visible = false
		return
	end
	local first: string? = nil
	for i, group in idsFor(currentTab) do
		local section = Ui.frame("Section", gridArea)
		section.LayoutOrder = i
		section.Size = UDim2.new(1, -8, 0, 0)
		section.AutomaticSize = Enum.AutomaticSize.Y
		Ui.list(section, Enum.FillDirection.Vertical, Theme.Space.Small)
		if group.title then
			Widgets.sectionTitle(section, group.title, 0)
		end
		local grid = Ui.frame("Grid", section)
		grid.LayoutOrder = 1
		grid.Size = UDim2.fromScale(1, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
		layout.CellPadding = UDim2.fromOffset(Theme.Space.Small + 2, Theme.Space.Small + 2)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		for order, id in group.ids do
			local card =
				Widgets.itemCard(grid, Strings.Weapons[id] or id, UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y), order)
			card.root.Name = id
			WeaponPreview.new(card.content, false).set(id)
			card.root.Activated:Connect(function()
				showDetail(id)
			end)
			cards[id] = card
			first = first or id
		end
	end
	-- PC: já mostra a primeira (ou a que estava escolhida); celular: o detalhe abre ao tocar
	local keep = if selected and cards[selected] then selected else first
	showDetail(if isTouch() then nil else keep)
end

local function build()
	modal = Widgets.modal("ArsenalScreen", 50, { title = A.Title, maxSize = Vector2.new(1040, 640) })
	local body = modal.body
	local T = A.Tabs
	tabs = Widgets.tabs(body, {
		{ id = "All", label = T.All },
		{ id = "Primary", label = T.Primary },
		{ id = "Secondary", label = T.Secondary },
		{ id = "Melee", label = T.Melee },
		{ id = "Ability", label = T.Ability },
	}, function(id: string)
		currentTab = id
		rebuild()
	end)

	local top = Theme.Touch.MinTarget + 12
	gridArea = Ui.scroll("Grid", Enum.ScrollingDirection.Y, body)
	gridArea.Position = UDim2.fromOffset(0, top)
	gridArea.Size = UDim2.new(0.62, 0, 1, -top)
	Ui.list(gridArea, Enum.FillDirection.Vertical, Theme.Space.Large)

	abilityArea = Ui.frame("Ability", body)
	abilityArea.Position = UDim2.fromOffset(0, top)
	abilityArea.Size = UDim2.new(1, 0, 1, -top)
	abilityArea.Visible = false
	local abilityLayout = Ui.list(abilityArea, Enum.FillDirection.Vertical, Theme.Space.Large)
	abilityLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	abilityLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local hint = Ui.label("Hint", Theme.Font.BodyStrong, Theme.TextSize.Body, Theme.Color.TextSecondary, abilityArea)
	hint.Size = UDim2.new(0.8, 0, 0, 40)
	hint.TextWrapped = true
	hint.Text = A.AbilityHint
	local open = Widgets.button(
		abilityArea,
		A.OpenCards,
		"primary",
		{ size = UDim2.fromOffset(220, Theme.PrimaryButtonMinHeight), order = 2 }
	)
	open.onClick(function()
		modal.close()
		CardsScreen.open()
	end)

	-- Painel de detalhe (direita; no celular, por cima da grade)
	local content: Frame
	detail, content = Ui.panel("Detail", body, 12)
	detail.AnchorPoint = Vector2.new(1, 0)
	detail.Position = UDim2.new(1, 0, 0, top)
	detail.Size = UDim2.new(0.38, -8, 1, -top)
	detail.Visible = false
	detail.ZIndex = 5

	local close = Widgets.iconButton(content, U.Back, function()
		showDetail(nil)
	end)
	close.ZIndex = 6
	local function refreshClose()
		close.Visible = isTouch()
	end
	refreshClose()
	InputDevice.onChanged(refreshClose)

	local previewBox = Ui.frame("Preview", content)
	previewBox.Size = UDim2.fromScale(1, 0.4)
	detailPreview = WeaponPreview.new(previewBox, true)

	local info = Ui.frame("Info", content)
	info.Position = UDim2.fromScale(0, 0.4)
	info.Size = UDim2.fromScale(1, 0.6)
	Ui.list(info, Enum.FillDirection.Vertical, 4)
	detailName = Ui.label("Name", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, info)
	detailName.Size = UDim2.new(1, 0, 0, 26)
	detailName.TextXAlignment = Enum.TextXAlignment.Left
	detailName.LayoutOrder = 1
	detailCategory = Ui.label("Category", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextSecondary, info)
	detailCategory.Size = UDim2.new(1, 0, 0, 16)
	detailCategory.TextXAlignment = Enum.TextXAlignment.Left
	detailCategory.LayoutOrder = 2
	detailDesc = Ui.paragraph("Desc", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextPrimary, info)
	detailDesc.LayoutOrder = 3

	Widgets.sectionTitle(info, A.Skins, 4)
	local skins = Ui.frame("Skins", info)
	skins.Size = UDim2.new(1, 0, 0, 48)
	skins.LayoutOrder = 5
	Ui.list(skins, Enum.FillDirection.Horizontal, Theme.Space.Small)
	local default = Widgets.itemCard(skins, A.DefaultSkin, UDim2.fromOffset(72, 46), 1)
	default.setSelected(true)
	default.title.TextSize = Theme.TextSize.Label
	local soon = Ui.label("Soon", Theme.Font.Body, Theme.TextSize.Label, Theme.Color.TextSecondary, info)
	soon.Size = UDim2.new(1, 0, 0, 16)
	soon.TextXAlignment = Enum.TextXAlignment.Left
	soon.Text = A.MoreSkinsSoon
	soon.LayoutOrder = 6

	equipButton = Widgets.button(info, A.Equip, "primary", {
		size = UDim2.new(1, 0, 0, Theme.Touch.MinTarget + 4),
		textSize = Theme.TextSize.Body,
		order = 7,
	})

	modal.gui.Parent = player:WaitForChild("PlayerGui")
	tabs.select("All")
end

local function fitLayout()
	-- Celular: a grade usa a largura toda e o detalhe cobre a metade direita
	local touch = isTouch()
	gridArea.Size = UDim2.new(if touch then 1 else 0.62, 0, 1, -(Theme.Touch.MinTarget + 12))
	detail.Size = UDim2.new(if touch then 0.5 else 0.38, -8, 1, -(Theme.Touch.MinTarget + 12))
end

function ArsenalScreen.open()
	if modal == nil then
		return
	end
	fitLayout()
	modal.open()
	rebuild()
end

function ArsenalScreen.Start()
	build()
	InputDevice.onChanged(function()
		if modal.isOpen() then
			fitLayout()
			rebuild()
		end
	end)
end

return ArsenalScreen
