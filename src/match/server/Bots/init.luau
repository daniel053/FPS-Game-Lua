--!strict
-- [BOTS] Bots de preenchimento na partida (docs/BOTS.md). TEMPORÁRIO: existem porque, no começo, quase
-- não há gente na fila. Desligar: BotConfig.Enabled = false. Remover de vez: docs/BOTS.md.
--
-- Quem decide QUANDO há bots é o MatchService (completa a sala até BotConfig.Match.FillTo, na hora em
-- que a partida começa). Aqui ficam a identidade (nome, elo mostrado), o corpo, o cérebro (BotAgent),
-- as escolhas de arma e carta e os abates de cada bot. Os bots pensam no servidor, num laço só.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local BotConfig = require(Shared.Config.BotConfig)
local BotRules = require(Shared.Bots.BotRules)
local CardRules = require(Shared.Cards.CardRules)
local LoadoutRules = require(Shared.Match.LoadoutRules)
local Strings = require(Shared.Config.Strings)

local Combatants = require(ServerScriptService.Combat.Combatants)

local BotAgent = require(script.BotAgent)
local BotBody = require(script.BotBody)

export type Identity = { name: string, userId: number, rankTier: string }

local BotService = {}

local rng = Random.new()
local agents: { [string]: BotAgent.Agent } = {} -- pela chave do membro da partida
local kills: { [string]: number } = {}
local usedNames: { [string]: boolean } = {}
local counter = 0
local killListeners: { () -> () } = {}
local errored: { [BotAgent.Agent]: boolean } = {}

function BotService.isEnabled(): boolean
	return BotConfig.Enabled
end

-- Nome de jogador, UserId de mentira (negativo, nunca de alguém de verdade) e elo mostrado no placar.
function BotService.newIdentity(): Identity
	counter += 1
	local tiers = BotConfig.DisplayTiers
	return {
		name = BotRules.makeName(Strings.Bots, rng, usedNames),
		userId = BotConfig.UserIdBase - counter,
		rankTier = tiers[rng:NextInteger(1, #tiers)],
	}
end

-- Nova partida: tira todos os bots e zera abates e nomes.
function BotService.reset()
	for _, agent in agents do
		BotAgent.destroy(agent)
	end
	table.clear(agents)
	table.clear(kills)
	table.clear(usedNames)
	table.clear(errored)
end

-- Bot na base da ilha (solto, sem armas até o combate). Devolve o combatente (ou nil se falhou).
function BotService.spawn(
	key: string,
	name: string,
	teamId: string,
	island: number,
	side: number,
	cframe: CFrame
): Combatants.Combatant?
	local old = agents[key]
	if old then
		BotAgent.destroy(old)
		agents[key] = nil
	end
	local combatant = BotBody.spawn(name, teamId, island, cframe, rng)
	if combatant == nil then
		return nil
	end
	local agent = BotAgent.new(key, combatant, island, side, rng, function(_victim: Combatants.Combatant)
		kills[key] = (kills[key] or 0) + 1
		for _, listener in killListeners do
			task.spawn(listener)
		end
	end)
	if agent == nil then
		combatant.model:Destroy()
		return nil
	end
	agents[key] = agent
	-- O corpo some (mirante, derrubado, fim da rodada): o cérebro para junto
	combatant.model.Destroying:Connect(function()
		if agents[key] == agent then
			agents[key] = nil
		end
		BotAgent.destroy(agent)
	end)
	return combatant
end

-- Armas da rodada: uma primária e uma pistola quaisquer das liberadas (bots não têm perfil).
function BotService.chooseLoadout(options: LoadoutRules.Options): (string?, string?)
	return BotRules.pickLoadout(options.primaries, options.secondaries, rng)
end

-- Carta básica da partida (sorteada entre C, Q e E).
function BotService.chooseCard(): string?
	local basic = BotRules.pickCards(rng)
	return basic
end

-- Começo do combate: armas e cartas da rodada (a ult das cartas iniciais, a partir da 4ª rodada).
function BotService.arm(
	key: string,
	primary: string?,
	secondary: string,
	basicCard: string?,
	round: number,
	combatStart: number
)
	local agent = agents[key]
	if agent == nil then
		return
	end
	local _, ult = BotRules.pickCards(rng)
	BotAgent.arm(agent, primary, secondary, CardRules.roundCards(basicCard, ult, round), combatStart)
end

function BotService.killsOf(key: string): number
	return kills[key] or 0
end

-- Um bot derrubou alguém (o placar mostra os abates dos bots).
function BotService.onKill(listener: () -> ())
	table.insert(killListeners, listener)
end

-- Preparação: quanto o bot "demora" para confirmar a escolha.
function BotService.confirmDelay(): number
	return BotRules.between(BotConfig.ConfirmSeconds, rng)
end

local function run(agent: BotAgent.Agent, fn: (BotAgent.Agent, number, number) -> (), now: number, dt: number)
	local ok, err = pcall(function(): string?
		fn(agent, now, dt)
		return nil
	end)
	if not ok and not errored[agent] then
		errored[agent] = true -- avisa uma vez por bot, sem encher o Output a cada quadro
		warn(`[Bots] Erro no bot {agent.key}: {err}`)
	end
end

local function think(agent: BotAgent.Agent, now: number, _dt: number)
	BotAgent.think(agent, now)
end

function BotService.Start()
	if not BotConfig.Enabled then
		return
	end
	-- Levou tiro de um jogador: o bot percebe quem atirou
	Combatants.onDamaged(function(target: Combatants.Combatant, source: Combatants.DamageSource?, _dealt: number)
		local attacker = source and source.player
		if attacker == nil then
			return
		end
		local attackerCombatant = Combatants.getByPlayer(attacker)
		if attackerCombatant then
			BotAgent.alert(target, attackerCombatant)
		end
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		local now = workspace:GetServerTimeNow()
		for _, agent in agents do
			if now >= agent.nextThinkAt then
				agent.nextThinkAt = now + BotConfig.Movement.ThinkSeconds
				run(agent, think, now, dt)
			end
			run(agent, BotAgent.step, now, dt)
		end
	end)
end

return BotService
