--!strict
-- Avatar redondo de um jogador (rosto do Roblox) com anel na cor da equipe (HUD, placar e lobby).
-- Jogadores de teste (UserId ≤ 0) e rostos que não carregam mostram a inicial do nome.
-- Os rostos ficam em cache (uma busca por jogador).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local TextUtil = require(Shared.TextUtil)
local Theme = require(Shared.Config.Theme)
local Ui = require(Shared.Ui.Ui)

export type Avatar = {
	root: Frame,
	image: ImageLabel,
	initial: TextLabel,
	ring: UIStroke,
	userId: number?,
}

local Avatars = {}

local cache: { [number]: string } = {}
local pending: { [number]: { (string) -> () } } = {}

local function fetch(userId: number, callback: (string) -> ())
	local cached = cache[userId]
	if cached then
		callback(cached)
		return
	end
	local waiting = pending[userId]
	if waiting then
		table.insert(waiting, callback)
		return
	end
	pending[userId] = { callback }
	task.spawn(function()
		local ok, content = pcall(function(): string
			local image =
				Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
			return image
		end)
		local list: { (string) -> () } = pending[userId] or {}
		pending[userId] = nil
		if ok and typeof(content) == "string" then
			cache[userId] = content
			for _, cb in list do
				task.spawn(cb, content)
			end
		end
	end)
end

function Avatars.new(parent: Instance, size: number): Avatar
	local root = Ui.frame("Avatar", parent)
	root.Size = UDim2.fromOffset(size, size)
	root.BackgroundTransparency = 0
	root.BackgroundColor3 = Theme.Color.PanelRaised
	Ui.corner(root, size)
	local ring = Ui.stroke(root, Theme.Color.PanelBorder, 2)

	local initial = Ui.label("Initial", Theme.Font.Title, math.floor(size * 0.5), Theme.Color.TextPrimary, root)
	initial.Size = UDim2.fromScale(1, 1)

	local image = Instance.new("ImageLabel")
	image.Name = "Face"
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = ""
	Ui.corner(image, size)
	image.Parent = root

	return { root = root, image = image, initial = initial, ring = ring, userId = nil }
end

-- color: anel na cor da equipe; faded: jogador que saiu (fica apagado).
function Avatars.set(avatar: Avatar, userId: number, name: string, color: Color3, faded: boolean?)
	avatar.ring.Color = color
	avatar.root.BackgroundTransparency = if faded then 0.6 else 0
	avatar.image.ImageTransparency = if faded then 0.6 else 0
	avatar.initial.Text = TextUtil.upper(string.match(name, utf8.charpattern) or "")
	if avatar.userId == userId then
		return
	end
	avatar.userId = userId
	avatar.image.Image = ""
	avatar.initial.Visible = true
	if userId > 0 then
		fetch(userId, function(content: string)
			if avatar.userId == userId then
				avatar.image.Image = content
				avatar.initial.Visible = false
			end
		end)
	end
end

return Avatars
