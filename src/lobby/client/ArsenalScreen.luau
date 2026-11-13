--!strict
-- Arsenal (ESTILO T5, revisto pelo dono do projeto na F7; referência docs/referencias/ref-t5-arsenal.png):
-- ver todas as armas e escolher a SKIN de cada uma. Não escolhe a arma da partida (isso é no modal de
-- preparação). As armas são as mesmas para todos; o que muda é a skin.
--   * Tudo numa tela, SEM abas e SEM rolagem: as 18 armas + o corpo a corpo agrupados por categoria,
--     em 4 linhas (Pistolas · Submetralhadoras + Escopetas + Corpo a corpo · Fuzis leves + Fuzis ·
--     Snipers + Metralhadoras). Os cartões se ajustam ao espaço da tela.
--   * Painel de detalhe à direita: a arma em 3D girando devagar, nome, categoria, uma frase, barras de
--     Dano, Cadência, Alcance e Mobilidade, EQUIPAR e, embaixo, a fila de SKINS.
--   * Catálogo, compra e equipar de verdade são da F9: por enquanto cada arma só tem a skin "Padrão",
--     já equipada; os outros espaços da fila aparecem com cadeado.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Strings = require(Shared.Config.Strings)
local TextUtil = require(Shared.TextUtil)
local Theme = require(Shared.Config.Theme)
local Ui = require(Shared.Ui.Ui)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WeaponStats = require(Shared.Combat.WeaponStats)

local WeaponPreview = require(script.Parent.Parent.Common.Ui.WeaponPreview)
local Widgets = require(script.Parent.Parent.Common.Ui.Widgets)

local A = Strings.Arsenal
local U = Strings.Ui
local MELEE = "Melee"
-- Linhas da grade: cada linha junta categorias até 5 cartões
local ROWS: { { string } } = {
	{ "Pistol" },
	{ "SMG", "Shotgun", MELEE },
	{ "LightRifle", "Rifle" },
	{ "Sniper", "MachineGun" },
}
local COLUMNS = 5
local CARD_GAP = 6
local GROUP_GAP = 14
local ROW_GAP = 8
local TITLE_HEIGHT = 14
local MIN_CARD_HEIGHT = Theme.Touch.MinTarget
local SKIN_SLOTS = 5 -- espaços na fila de skins (os que não existem ainda ficam com cadeado)
local STAT_ROW = 18

type Group = { frame: Frame, cards: Frame, count: number }

local ArsenalScreen = {}

local player = Players.LocalPlayer
local modal: Widgets.Modal
local grid: Frame
local groups: { Group } = {}
local rowFrames: { Frame } = {}
local cardSizes: { GuiObject } = {}
local detailPreview: WeaponPreview.Preview
local detailName: TextLabel
local detailCategory: TextLabel
local detailDesc: TextLabel
local statFills: { Frame } = {}
local equipButton: Widgets.Button
local cards: { [string]: Widgets.ItemCard } = {}
local selected: string = "weapon_bolinha"

local function idsOf(category: string): { string }
	if category == MELEE then
		return { WeaponConfig.Melee.id }
	end
	local list = {}
	for _, def in WeaponConfig.Weapons do
		if def.category == category then
			table.insert(list, def.id)
		end
	end
	return list
end

local function categoryName(category: string): string
	return if category == MELEE then A.Melee else (Strings.WeaponCategories[category] or category)
end

local function categoryOfId(id: string): string
	if id == WeaponConfig.Melee.id then
		return MELEE
	end
	local def = WeaponConfig.get(id)
	return if def then def.category else ""
end

local function showDetail(id: string)
	selected = id
	for weaponId, card in cards do
		card.setSelected(weaponId == id)
	end
	detailPreview.set(id)
	detailName.Text = TextUtil.upper(Strings.Weapons[id] or id)
	detailCategory.Text = TextUtil.upper(categoryName(categoryOfId(id)))
	detailDesc.Text = A.Descriptions[id] or ""
	local stats = WeaponStats.get(id)
	if stats then
		for i, value in { stats.damage, stats.fireRate, stats.range, stats.mobility } do
			statFills[i].Size = UDim2.fromScale(value, 1)
		end
	end
	-- Só existe a skin Padrão, já equipada (catálogo e loja na F9)
	equipButton.setText(A.Equipped .. " " .. U.Check)
	equipButton.setEnabled(false)
end

-- Tamanho dos cartões a partir do espaço da grade: 5 colunas × 4 linhas sem rolagem.
local function layoutGrid()
	local size = grid.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local width = math.floor((size.X - (COLUMNS - 1) * CARD_GAP - 2 * GROUP_GAP) / COLUMNS)
	local height = math.floor((size.Y - #ROWS * (TITLE_HEIGHT + 4) - (#ROWS - 1) * ROW_GAP) / #ROWS)
	height = math.clamp(height, MIN_CARD_HEIGHT, math.floor(width * 0.95))
	for _, card in cardSizes do
		card.Size = UDim2.fromOffset(width, height)
	end
	for _, group in groups do
		group.cards.Size = UDim2.fromOffset(group.count * width + (group.count - 1) * CARD_GAP, height)
		group.frame.Size = UDim2.fromOffset(group.cards.Size.X.Offset, TITLE_HEIGHT + 4 + height)
	end
	for _, row in rowFrames do
		row.Size = UDim2.new(1, 0, 0, TITLE_HEIGHT + 4 + height)
	end
end

local function buildGrid(parent: Frame)
	grid = Ui.frame("Grid", parent)
	grid.Size = UDim2.new(0.6, -8, 1, 0)
	Ui.list(grid, Enum.FillDirection.Vertical, ROW_GAP)
	for r, categories in ROWS do
		local row = Ui.frame(`Row{r}`, grid)
		row.LayoutOrder = r
		Ui.list(row, Enum.FillDirection.Horizontal, GROUP_GAP)
		table.insert(rowFrames, row)
		for g, category in categories do
			local ids = idsOf(category)
			local frame = Ui.frame(category, row)
			frame.LayoutOrder = g
			local title = Ui.label("Title", Theme.Font.Title, Theme.TextSize.Label, Theme.Color.TextPrimary, frame)
			title.Size = UDim2.new(1, 60, 0, TITLE_HEIGHT)
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.RichText = true
			title.Text = Widgets.titleText(categoryName(category))
			local holder = Ui.frame("Cards", frame)
			holder.Position = UDim2.fromOffset(0, TITLE_HEIGHT + 4)
			Ui.list(holder, Enum.FillDirection.Horizontal, CARD_GAP)
			for order, id in ids do
				local card = Widgets.itemCard(holder, Strings.Weapons[id] or id, UDim2.fromOffset(60, 50), order)
				card.root.Name = id
				card.title.TextSize = Theme.TextSize.Label
				local look = Theme.WeaponLook[id]
				card.setMarker(if look then look.accent else nil)
				WeaponPreview.new(card.content, false).set(id)
				card.root.Activated:Connect(function()
					showDetail(id)
				end)
				cards[id] = card
				table.insert(cardSizes, card.root)
			end
			table.insert(groups, { frame = frame, cards = holder, count = #ids })
		end
	end
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutGrid)
end

local function statRow(parent: Instance, order: number, name: string): Frame
	local row = Ui.frame("Stat", parent)
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, STAT_ROW)
	local label = Ui.label("Name", Theme.Font.Title, Theme.TextSize.Label, Theme.Color.TextSecondary, row)
	label.Size = UDim2.fromScale(0.34, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = TextUtil.upper(name)
	local track = Ui.frame("Track", row)
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.fromScale(1, 0.5)
	track.Size = UDim2.new(0.66, 0, 0, 8)
	track.BackgroundTransparency = 0
	track.BackgroundColor3 = Theme.Color.PanelRaised
	Ui.corner(track, 4)
	local fill = Ui.frame("Fill", track)
	fill.BackgroundTransparency = 0
	fill.BackgroundColor3 = Theme.Color.Accent
	fill.Size = UDim2.fromScale(0.5, 1)
	Ui.corner(fill, 4)
	return fill
end

local function buildDetail(parent: Frame)
	local detail, content = Ui.panel("Detail", parent, 12)
	detail.AnchorPoint = Vector2.new(1, 0)
	detail.Position = UDim2.fromScale(1, 0)
	detail.Size = UDim2.new(0.4, -8, 1, 0)

	-- Rola só se a tela for baixa demais (celular pequeno); a grade nunca rola
	local scroll = Ui.scroll("Scroll", Enum.ScrollingDirection.Y, content)
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.ScrollBarThickness = 3
	Ui.list(scroll, Enum.FillDirection.Vertical, 6)

	local previewBox = Ui.frame("Preview", scroll)
	previewBox.Size = UDim2.new(1, -6, 0, 150)
	previewBox.LayoutOrder = 1
	detailPreview = WeaponPreview.new(previewBox, true)

	detailName = Ui.label("WeaponName", Theme.Font.Title, Theme.TextSize.Title, Theme.Color.TextPrimary, scroll)
	detailName.Size = UDim2.new(1, -6, 0, 26)
	detailName.TextXAlignment = Enum.TextXAlignment.Left
	detailName.LayoutOrder = 2
	detailCategory =
		Ui.label("Category", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextSecondary, scroll)
	detailCategory.Size = UDim2.new(1, -6, 0, 14)
	detailCategory.TextXAlignment = Enum.TextXAlignment.Left
	detailCategory.LayoutOrder = 3
	detailDesc = Ui.paragraph("Desc", Theme.Font.Body, Theme.TextSize.Body, Theme.Color.TextPrimary, scroll)
	detailDesc.Size = UDim2.new(1, -6, 0, 0)
	detailDesc.LayoutOrder = 4

	local S = A.Stats
	for i, name in { S.Damage, S.FireRate, S.Range, S.Mobility } do
		statFills[i] = statRow(scroll, 4 + i, name)
	end

	equipButton = Widgets.button(scroll, A.Equip, "primary", {
		size = UDim2.new(1, -6, 0, Theme.Touch.MinTarget + 4),
		textSize = Theme.TextSize.Body,
		order = 10,
	})

	-- Skins embaixo (ESTILO T5): a Padrão e os espaços das próximas (F9)
	Widgets.sectionTitle(scroll, A.Skins, 11)
	local skins = Ui.frame("Skins", scroll)
	skins.Size = UDim2.new(1, -6, 0, 50)
	skins.LayoutOrder = 12
	Ui.list(skins, Enum.FillDirection.Horizontal, Theme.Space.Small)
	local slot = UDim2.new(1 / SKIN_SLOTS, -Theme.Space.Small, 1, 0)
	local default = Widgets.itemCard(skins, A.DefaultSkin, slot, 1)
	default.title.TextSize = Theme.TextSize.Label
	default.setSelected(true)
	for i = 2, SKIN_SLOTS do
		local locked = Widgets.itemCard(skins, "", slot, i)
		locked.title.Visible = false
		locked.setLocked(true, nil)
	end
	local soon = Ui.label("Soon", Theme.Font.Body, Theme.TextSize.Label, Theme.Color.TextSecondary, scroll)
	soon.Size = UDim2.new(1, -6, 0, 16)
	soon.TextXAlignment = Enum.TextXAlignment.Left
	soon.Text = A.MoreSkinsSoon
	soon.LayoutOrder = 13
end

local function build()
	modal = Widgets.modal("ArsenalScreen", 50, {
		title = A.Title,
		size = UDim2.fromScale(0.8, 0.84),
		touchSize = UDim2.fromScale(0.97, 0.95),
		maxSize = Vector2.new(1120, 680),
	})
	buildGrid(modal.body)
	buildDetail(modal.body)
	modal.gui.Parent = player:WaitForChild("PlayerGui")
	showDetail(selected)
end

function ArsenalScreen.open()
	if modal == nil then
		return
	end
	modal.open()
	task.defer(layoutGrid)
	showDetail(selected)
end

function ArsenalScreen.Start()
	build()
end

return ArsenalScreen
