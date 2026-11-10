--!strict
-- Jogador novo cai no tutorial (GDD 5.1): ao entrar no lobby com `tutorialDone = false`, vai para
-- o place Tutorial, num servidor só dele. Quem já terminou nunca é mandado de volta.
-- No Studio não há teleporte: o lobby funciona normalmente e o Output avisa.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Common.DataService)
local PlaceTeleport = require(ServerScriptService.Common.PlaceTeleport)

local TutorialGate = {}

local function onPlayerAdded(player: Player)
	local profile = DataService.waitForProfile(player)
	if profile == nil or player.Parent == nil or profile.tutorialDone then
		return
	end
	if not PlaceTeleport.sendToTutorial(player) then
		warn(`[Tutorial] {player.Name} ainda não fez o tutorial; sem teleporte aqui (Studio?), segue no lobby.`)
	end
end

-- Pode o jogador entrar na fila? (no jogo publicado, quem não fez o tutorial já foi levado embora)
function TutorialGate.isDone(player: Player): boolean
	local profile = DataService.getProfile(player)
	return profile ~= nil and profile.tutorialDone
end

function TutorialGate.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return TutorialGate
