--!strict
-- Pontos de recarga de escudo das ilhas (GDD 15.1, regras em `Shared/Match/ShieldPointRules`).
-- O servidor decide quem pegou: confere a posição de cada combatente vivo que está numa ilha.
-- O ponto usado apaga (placa escura e atributo `ShieldPointActive` = false) e reacende sozinho.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local CharacterConfig = require(Shared.Config.CharacterConfig)
local IslandCommon = require(Shared.Maps.IslandCommon)
local ShieldPointRules = require(Shared.Match.ShieldPointRules)
local Theme = require(Shared.Config.Theme)
local Combatants = require(script.Parent.Parent.Combat.Combatants)

local ShieldPoints = {}

ShieldPoints.ActiveAttribute = "ShieldPointActive"

type Point = {
	model: Model,
	position: Vector3, -- a placa, no chão
	readyAt: number?,
	lit: boolean,
}

local CHECK_INTERVAL = 0.1

local points: { Point } = {}
local connection: RBXScriptConnection? = nil

local function setLit(point: Point, lit: boolean)
	point.lit = lit
	point.model:SetAttribute(ShieldPoints.ActiveAttribute, lit)
	local color = if lit then Theme.Match.ShieldPad else Theme.Match.ShieldPadOff
	for _, part in point.model:GetChildren() do
		if part:IsA("BasePart") and part.Name == "PadTop" then
			part.Color = color
		end
	end
end

-- Todos os pontos acesos (começo de cada rodada).
function ShieldPoints.reset()
	for _, point in points do
		point.readyAt = nil
		setLit(point, true)
	end
end

local function step()
	local now = os.clock()
	for _, point in points do
		local active = ShieldPointRules.isActive(point.readyAt, now)
		if active and not point.lit then
			setLit(point, true)
		end
		if active then
			for _, c in Combatants.all() do
				if
					c.island ~= nil
					and ShieldPointRules.canPickup(c.alive, c.health.shield, true)
					and ShieldPointRules.inReach(point.position, c.hitbox.Position)
				then
					c.health.shield = CharacterConfig.Health.MaxShield
					Combatants.publish(c)
					point.readyAt = ShieldPointRules.readyAfter(now)
					setLit(point, false)
					break
				end
			end
		end
	end
end

-- Liga os pontos de `world` (a pasta do mundo da partida). Chamar uma vez, depois de montar o mundo.
function ShieldPoints.start(world: Instance)
	points = {}
	for _, model in CollectionService:GetTagged(IslandCommon.ShieldPointTag) do
		if model:IsA("Model") and model:IsDescendantOf(world) then
			local pivot = model:GetPivot().Position
			local point: Point = { model = model, position = pivot, readyAt = nil, lit = true }
			table.insert(points, point)
			setLit(point, true)
		end
	end
	if connection then
		connection:Disconnect()
	end
	local elapsed = 0
	connection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= CHECK_INTERVAL then
			elapsed = 0
			step()
		end
	end)
end

return ShieldPoints
