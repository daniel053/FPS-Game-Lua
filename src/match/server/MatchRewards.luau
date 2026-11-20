--!strict
-- Recompensas de uma partida (F9, GDD 9, 10 e 4.8): conta o que cada jogador fez (rodadas, vitórias,
-- abates, mortes, dano, Viradas, rodadas 1v2) e, uma vez por partida, credita moedas
-- (EconomyService), elo (RankService) e estatísticas no perfil, e salva.
--
-- Quando credita (`settle`), sempre com a colocação da dupla:
--   * dupla eliminada: na hora em que cai (a colocação já está definida; quem fica para assistir
--     recebe o mesmo que receberia no fim);
--   * campeã e vice: no fim da partida;
--   * quem sai no meio ou volta ao lobby por ausência: antes de o perfil deixar o servidor
--     (DataService.onBeforeRelease), como se a dupla caísse naquele momento (RankConfig).
-- Uma partida interrompida pelo painel de teste (`cancel`) não credita nada para quem ainda não recebeu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local EconomyRules = require(Shared.Progression.EconomyRules)
local MatchTypes = require(Shared.Match.MatchTypes)

local Common = ServerScriptService.Common
local DataService = require(Common.DataService)
local EconomyService = require(Common.EconomyService)
local ProfileRules = require(Common.Data.ProfileRules)
local RankService = require(Common.RankService)
local Combatants = require(script.Parent.Parent.Combat.Combatants)

type Tally = {
	teamId: string,
	partnerUserId: number?, -- parceiro no começo (nil = jogou sozinho)
	roundsPlayed: number,
	roundsWon: number,
	kills: number,
	deaths: number,
	damageDealt: number,
	viradasWon: number,
	soloRoundsWon: number,
	killsByWeapon: { [string]: number },
	settled: boolean,
}

-- Para quem sai no meio: colocação "agora" e se ainda tinha o mesmo parceiro. nil = não credita.
export type LeaverContext = { placement: number, samePartner: boolean }

export type RoundResult = { won: boolean, virada: boolean, solo: boolean }

local MatchRewards = {}

local active = false
local teamCount = 0
local isPrivate = false
local isCasual = false -- [BOTS] partida com bots de preenchimento: moedas normais, elo parado
local tallies: { [Player]: Tally } = {}
local leaverContext: ((player: Player) -> LeaverContext?)? = nil
local settledCallback: ((player: Player, data: MatchTypes.RewardsData) -> ())? = nil

-- Começo da partida (duplas formadas). `entries` = jogadores de verdade com a dupla e o parceiro.
-- `casual` = partida com bots de preenchimento (docs/BOTS.md): não mexe no elo [BOTS].
function MatchRewards.begin(
	entries: { { player: Player, teamId: string, partnerUserId: number? } },
	teams: number,
	private: boolean,
	casual: boolean?
)
	table.clear(tallies)
	active = true
	isCasual = casual == true
	teamCount = teams
	isPrivate = private
	for _, entry in entries do
		tallies[entry.player] = {
			teamId = entry.teamId,
			partnerUserId = entry.partnerUserId,
			roundsPlayed = 0,
			roundsWon = 0,
			kills = 0,
			deaths = 0,
			damageDealt = 0,
			viradasWon = 0,
			soloRoundsWon = 0,
			killsByWeapon = {},
			settled = false,
		}
	end
end

-- Partida interrompida (painel de teste) ou servidor recomeçando: ninguém mais recebe.
function MatchRewards.cancel()
	active = false
	table.clear(tallies)
end

function MatchRewards.setLeaverContext(provider: (player: Player) -> LeaverContext?)
	leaverContext = provider
end

function MatchRewards.onSettled(callback: (player: Player, data: MatchTypes.RewardsData) -> ())
	settledCallback = callback
end

-- Fim de uma rodada para quem jogou (a dupla de folga não chama).
function MatchRewards.recordRound(player: Player, result: RoundResult)
	local tally = tallies[player]
	if not active or tally == nil or tally.settled then
		return
	end
	tally.roundsPlayed += 1
	if result.won then
		tally.roundsWon += 1
		if result.virada then
			tally.viradasWon += 1
		end
		if result.solo then
			tally.soloRoundsWon += 1
		end
	end
end

function MatchRewards.isSettled(player: Player): boolean
	local tally = tallies[player]
	return tally == nil or tally.settled
end

function MatchRewards.partnerOf(player: Player): number?
	local tally = tallies[player]
	return if tally then tally.partnerUserId else nil
end

-- Credita tudo uma vez só. `samePartner` = ainda com o parceiro do começo, sem ele ter saído.
function MatchRewards.settle(player: Player, placement: number?, samePartner: boolean): MatchTypes.RewardsData?
	local tally = tallies[player]
	if not active or tally == nil or tally.settled then
		return nil
	end
	if DataService.getProfile(player) == nil then
		return nil -- perfil não está aberto (Studio sem DataStore carrega um perfil falso, então isto é raro)
	end
	tally.settled = true
	local now = os.time()

	local coins = EconomyRules.matchCoins({
		roundsPlayed = tally.roundsPlayed,
		roundsWon = tally.roundsWon,
		kills = tally.kills,
	}, {
		placement = placement,
		samePartner = samePartner and tally.partnerUserId ~= nil,
		isPrivate = isPrivate,
		firstWinAvailable = EconomyService.firstWinAvailable(player, now) == true,
	})
	EconomyService.creditMatch(player, coins, now)

	DataService.update(player, function(profile)
		return ProfileRules.addMatchStats(profile, {
			placement = placement,
			roundsPlayed = tally.roundsPlayed,
			roundsWon = tally.roundsWon,
			kills = tally.kills,
			deaths = tally.deaths,
			damageDealt = tally.damageDealt,
			viradasWon = tally.viradasWon,
			soloRoundsWon = tally.soloRoundsWon,
			killsByWeapon = tally.killsByWeapon,
		})
	end)

	-- [BOTS] partida com bots não passa pelo elo (nem conta como partida ranqueada)
	local rank = if placement and not isCasual
		then RankService.applyMatch(player, { placement = placement, teamCount = teamCount }, isPrivate)
		else nil
	DataService.saveNow(player)

	local profile = DataService.getProfile(player)
	local points = if profile then profile.rank.points else 0
	local data: MatchTypes.RewardsData = {
		placement = placement,
		coins = coins.total,
		coinsBreakdown = {
			rounds = coins.rounds,
			wins = coins.wins,
			kills = coins.kills,
			placement = coins.placement,
			partnerBonus = coins.partnerBonus,
			firstWin = coins.firstWin,
			privateCut = coins.privateCut,
		},
		ranked = rank ~= nil and rank.ranked,
		casual = isCasual and not isPrivate, -- [BOTS]
		rankDelta = if rank then rank.delta else 0,
		rankPoints = if rank then rank.points else points,
		rankTier = if rank then rank.tier else "",
		rankTierBefore = if rank then rank.tierBefore else "",
		rankProtected = rank ~= nil and rank.protected,
		rankDoubled = rank ~= nil and rank.doubled,
	}
	print(`[Partida] Recompensas de {player.Name}: {placement or "-"}º, +{coins.total} moedas, {data.rankDelta} PE`)
	local callback = settledCallback
	if callback then
		task.spawn(callback, player, data)
	end
	return data
end

function MatchRewards.Start()
	-- Abates e mortes (o "N KILL" e o atributo Kills ficam no CombatService)
	Combatants.onKnocked(function(target: Combatants.Combatant, source: Combatants.DamageSource?)
		if not active then
			return
		end
		local victim = target.player
		local victimTally = victim and tallies[victim]
		if victimTally and not victimTally.settled then
			victimTally.deaths += 1
		end
		local killer = source and source.player
		if killer == nil or killer == victim then
			return
		end
		local tally = tallies[killer]
		if tally and not tally.settled then
			tally.kills += 1
			local weaponId = (source :: Combatants.DamageSource).weaponId
			tally.killsByWeapon[weaponId] = (tally.killsByWeapon[weaponId] or 0) + 1
		end
	end)
	Combatants.onDamaged(function(target: Combatants.Combatant, source: Combatants.DamageSource?, dealt: number)
		local attacker = source and source.player
		if not active or attacker == nil or attacker == target.player then
			return
		end
		local tally = tallies[attacker]
		if tally and not tally.settled then
			tally.damageDealt += dealt
		end
	end)
	-- Saiu no meio (ou vai ser teleportado antes de receber): credita com a colocação de agora.
	DataService.onBeforeRelease(function(player: Player)
		local tally = tallies[player]
		local provider = leaverContext
		if not active or tally == nil or tally.settled or provider == nil then
			return
		end
		local context = provider(player)
		if context then
			MatchRewards.settle(player, context.placement, context.samePartner)
		end
	end)
end

return MatchRewards
