--!strict
-- Arsenal (ESTILO T5, revisto pelo dono do projeto na F7; referência docs/referencias/ref-t5-arsenal.png):
-- ver todas as armas e escolher a SKIN de cada uma. Não escolhe a arma da partida (isso é no modal de
-- preparação). As armas são as mesmas para todos; o que muda é a skin.
--   * Tudo numa tela, SEM abas e SEM rolagem: as 18 armas + o corpo a corpo agrupados por categoria,
--     em 4 linhas (Pistolas · Submetralhadoras + Escopetas + Corpo a corpo · Fuzis leves + Fuzis ·
--     Snipers + Metralhadoras). Os cartões se ajustam ao espaço da tela e mostram a skin equipada.
--   * Painel de detalhe à direita: a arma em 3D girando devagar (com a skin escolhida), nome,
--     categoria, uma frase, barras de Dano, Cadência, Alcance e Mobilidade, o botão principal e, embaixo,
--     a fila de SKINS (F9): Padrão + as skins do catálogo, com moldura de raridade; as que o jogador não
--     tem ficam com cadeado e preço.
--   * O botão principal age sobre a skin escolhida na fila: COMPRAR (preço) se o jogador não tem,
--     EQUIPAR se tem, EQUIPADA se já está em uso. O servidor confere tudo (ShopService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local ShopCatalog = require(Shared.Config.ShopCatalog)
local Strings = require(Shared.Config.Strings)
local TextUtil = require(Shared.TextUtil)
local Theme = require(Shared.Config.Theme)
local Ui = require(Shared.Ui.Ui)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local WeaponStats = require(Shared.Combat.WeaponStats)

local PlayerDataClient = require(script.Parent.Parent.Common.PlayerDataClient)
local WeaponPreview = require(script.Parent.Parent.Common.Ui.WeaponPreview)
local Widgets = require(script.Parent.Parent.Common.Ui.Widgets)

local A = Strings.Arsenal
local U = Strings.Ui
local MELEE = "Melee"
local DEFAULT = "default" -- a skin Padrão na fila
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
local SKIN_SLOTS = 1 + #ShopCatalog.Themes -- Padrão + um espaço por tema
local STAT_ROW = 18
local NOTICE_SECONDS = 4

type Group = { frame: Frame, cards: Frame, count: number }
type SkinSlot = { card: Widgets.ItemCard, swatch: Frame, id: string }

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
local skinRow: Frame
local skinSlots: { SkinSlot } = {}
local skinInfo: TextLabel
local balanceLabel: TextLabel
local noticeLabel: TextLabel
local noticeUntil = 0
local cards: { [string]: Widgets.ItemCard } = {}
local gridPreviews: { [string]: { preview: WeaponPreview.Preview, skin: string? } } = {}
local selected: string = "weapon_bolinha"
local selectedSkin: string = DEFAULT
local pending = false
local shopRequest: RemoteEvent

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

-- Skins no perfil --------------------------------------------------------------------------------

local function equippedFor(weaponId: string): string?
	local profile = PlayerDataClient.get()
	if profile == nil then
		return nil
	end
	local equipped = profile.cosmetics.equipped
	if weaponId == WeaponConfig.Melee.id then
		return equipped.melee
	end
	return equipped.weapons[weaponId]
end

local function owns(skinId: string): boolean
	local profile = PlayerDataClient.get()
	return profile ~= nil and profile.cosmetics.owned[skinId] ~= nil
end

local function coins(): number
	local profile = PlayerDataClient.get()
	return if profile then profile.coins else 0
end

local function themeName(skin: ShopCatalog.SkinDef): string
	return if skin.theme then (Strings.Skins.Themes[skin.theme] or skin.theme) else skin.id
end

local function rarityText(rarity: string): string
	local info = Strings.Rarity[rarity]
	return if info then info.icon .. " " .. info.name else rarity
end

local function notice(text: string)
	noticeLabel.Text = text
	noticeUntil = os.clock() + NOTICE_SECONDS
	noticeLabel.Visible = true
	local stamp = noticeUntil
	task.delay(NOTICE_SECONDS, function()
		if noticeUntil == stamp then
			noticeLabel.Visible = false
		end
	end)
end

-- Botão principal e textos da skin escolhida.
local function refreshAction()
	local equipped = equippedFor(selected)
	local skin = if selectedSkin ~= DEFAULT then ShopCatalog.getSkin(selectedSkin) else nil
	balanceLabel.Text = string.format(A.Balance, U.Coin, coins())
	if skin == nil then
		skinInfo.Text = A.DefaultSkin
		local isOn = equipped == nil
		equipButton.setText(if isOn then A.Equipped .. " " .. U.Check else A.Equip)
		equipButton.setKind(if isOn then "secondary" else "primary")
		equipButton.setEnabled(not isOn and not pending)
		return
	end
	skinInfo.Text = string.format(A.SkinLine, themeName(skin), rarityText(skin.rarity))
	if owns(skin.id) then
		local isOn = equipped == skin.id
		equipButton.setText(if isOn then A.Equipped .. " " .. U.Check else A.Equip)
		equipButton.setKind(if isOn then "secondary" else "primary")
		equipButton.setEnabled(not isOn and not pending)
	elseif skin.priceCoins then
		equipButton.setText(string.format(A.Buy, U.Coin, skin.priceCoins))
		equipButton.setKind("primary")
		equipButton.setEnabled(coins() >= skin.priceCoins and not pending)
	else
		equipButton.setText(A.NotForSale)
		equipButton.setKind("secondary")
		equipButton.setEnabled(false)
	end
end

local function paintSwatch(swatch: Frame, weaponId: string, skin: ShopCatalog.SkinDef?)
	local look = if skin and skin.theme then Theme.SkinLook[skin.theme] else nil
	local base = Theme.WeaponLook[weaponId]
	local colors = if look
		then { look.body, look.dark, look.accent }
		elseif base then { base.body, base.dark, base.accent }
		else { Theme.Combat.WeaponBody, Theme.Combat.WeaponDark, Theme.Combat.WeaponLight }
	for i, stripe in swatch:GetChildren() do
		if stripe:IsA("Frame") then
			local index = tonumber(string.match(stripe.Name, "%d+")) or i
			stripe.BackgroundColor3 = colors[index] or colors[1]
		end
	end
end

-- Fila de skins da arma escolhida.
local function refreshSkins()
	local skins = ShopCatalog.skinsFor(selected)
	local equipped = equippedFor(selected)
	for i, slot in skinSlots do
		local skin = if i == 1 then nil else skins[i - 1]
		slot.id = if i == 1 then DEFAULT else (if skin then skin.id else "")
		slot.card.root.Visible = i == 1 or skin ~= nil
		slot.card.setSelected(slot.id == selectedSkin)
		if skin then
			slot.card.title.Text = TextUtil.upper(themeName(skin))
			Widgets.rarityFrame(slot.card, skin.rarity)
			local has = owns(skin.id)
			local price = skin.priceCoins
			slot.card.setLocked(not has, if price then string.format(A.SkinPrice, U.Coin, price) else nil)
			slot.card.setMarker(if equipped == skin.id then Theme.Color.Success else nil)
		else
			slot.card.title.Text = TextUtil.upper(A.DefaultSkin)
			slot.card.setBorder(Theme.Color.PanelBorder, 1)
			slot.card.setLocked(false, nil)
			slot.card.setMarker(if equipped == nil then Theme.Color.Success else nil)
		end
		paintSwatch(slot.swatch, selected, skin)
	end
	detailPreview.set(selected, if selectedSkin ~= DEFAULT then selectedSkin else nil)
	refreshAction()
end

-- Cartões da grade com a skin equipada (só refaz o modelo quando a skin muda).
local function refreshGridSkins()
	for id, entry in gridPreviews do
		local skin = equippedFor(id)
		if skin ~= entry.skin then
			entry.skin = skin
			entry.preview.set(id, skin)
		end
	end
end

local function showDetail(id: string)
	selected = id
	selectedSkin = equippedFor(id) or DEFAULT
	for weaponId, card in cards do
		card.setSelected(weaponId == id)
	end
	detailName.Text = TextUtil.upper(Strings.Weapons[id] or id)
	detailCategory.Text = TextUtil.upper(categoryName(categoryOfId(id)))
	detailDesc.Text = A.Descriptions[id] or ""
	local stats = WeaponStats.get(id)
	if stats then
		for i, value in { stats.damage, stats.fireRate, stats.range, stats.mobility } do
			statFills[i].Size = UDim2.fromScale(value, 1)
		end
	end
	refreshSkins()
end

local function onAction()
	if pending then
		return
	end
	local skin = if selectedSkin ~= DEFAULT then ShopCatalog.getSkin(selectedSkin) else nil
	if skin == nil then
		shopRequest:FireServer("Unequip", selected)
	elseif owns(skin.id) then
		shopRequest:FireServer("Equip", skin.id)
	else
		shopRequest:FireServer("Buy", skin.id)
	end
	pending = true
	refreshAction()
	-- Sem resposta (rede): libera o botão de novo
	task.delay(5, function()
		if pending then
			pending = false
			refreshAction()
		end
	end)
end

-- Montagem ---------------------------------------------------------------------------------------

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
				local preview = WeaponPreview.new(card.content, false)
				local skin = equippedFor(id)
				preview.set(id, skin)
				gridPreviews[id] = { preview = preview, skin = skin }
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

-- Amostra de cores da skin (3 faixas: corpo, partes escuras, destaque), no lugar de mais um modelo 3D.
local function makeSwatch(parent: Instance): Frame
	local swatch = Ui.frame("Swatch", parent)
	swatch.AnchorPoint = Vector2.new(0.5, 0.5)
	swatch.Position = UDim2.fromScale(0.5, 0.5)
	swatch.Size = UDim2.fromScale(0.8, 0.7)
	swatch.ClipsDescendants = true
	Ui.corner(swatch, 6)
	for i, height in { 0.5, 0.3, 0.2 } do
		local stripe = Ui.frame(`Stripe{i}`, swatch)
		stripe.BackgroundTransparency = 0
		stripe.Size = UDim2.fromScale(1, height)
		stripe.Position = UDim2.fromScale(0, if i == 1 then 0 elseif i == 2 then 0.5 else 0.8)
	end
	return swatch
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
	equipButton.onClick(onAction)

	-- Skins embaixo (ESTILO T5): a Padrão e as do catálogo (F9)
	Widgets.sectionTitle(scroll, A.Skins, 11)
	skinRow = Ui.frame("Skins", scroll)
	skinRow.Size = UDim2.new(1, -6, 0, 58)
	skinRow.LayoutOrder = 12
	Ui.list(skinRow, Enum.FillDirection.Horizontal, Theme.Space.Small)
	local slotSize = UDim2.new(1 / SKIN_SLOTS, -Theme.Space.Small, 1, 0)
	for i = 1, SKIN_SLOTS do
		local card = Widgets.itemCard(skinRow, "", slotSize, i)
		card.title.TextSize = Theme.TextSize.Label - 1
		local swatch = makeSwatch(card.content)
		local slot: SkinSlot = { card = card, swatch = swatch, id = "" }
		card.root.Activated:Connect(function()
			if slot.id ~= "" then
				selectedSkin = slot.id
				refreshSkins()
			end
		end)
		skinSlots[i] = slot
	end

	skinInfo = Ui.label("SkinInfo", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.TextPrimary, scroll)
	skinInfo.Size = UDim2.new(1, -6, 0, 16)
	skinInfo.TextXAlignment = Enum.TextXAlignment.Left
	skinInfo.LayoutOrder = 13
	balanceLabel = Ui.label("Balance", Theme.Font.Body, Theme.TextSize.Label, Theme.Color.TextSecondary, scroll)
	balanceLabel.Size = UDim2.new(1, -6, 0, 16)
	balanceLabel.TextXAlignment = Enum.TextXAlignment.Left
	balanceLabel.LayoutOrder = 14
	noticeLabel = Ui.label("Notice", Theme.Font.BodyStrong, Theme.TextSize.Label, Theme.Color.Success, scroll)
	noticeLabel.Size = UDim2.new(1, -6, 0, 16)
	noticeLabel.TextXAlignment = Enum.TextXAlignment.Left
	noticeLabel.TextWrapped = true
	noticeLabel.LayoutOrder = 15
	noticeLabel.Visible = false
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
	refreshGridSkins()
	showDetail(selected)
end

function ArsenalScreen.Start()
	shopRequest = Remotes.event("ShopRequest")
	build()
	Remotes.event("ShopResult").OnClientEvent:Connect(function(ok: boolean, key: string)
		pending = false
		local text = A.Results[key] or A.Results.Failed
		noticeLabel.TextColor3 = if ok then Theme.Color.Success else Theme.Color.TextSecondary
		notice(text)
		refreshAction()
	end)
	PlayerDataClient.onChanged(function()
		if modal.isOpen() then
			refreshGridSkins()
			refreshSkins()
		end
	end)
end

return ArsenalScreen
