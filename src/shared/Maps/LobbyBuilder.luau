--!strict
-- Lobby 3D (ESTILO T3, FASES F10): a ilha onde o jogador fica e, ao fundo, o mundo da partida.
--
--   * Ilha do lobby (`island`, montada pelo SERVIDOR): pracinha flutuante com o kit da Praça
--     (KIT-MODULAR 4): piso de lajota, mureta com pilares, árvores, postes, bancos e barracas, e
--     estandartes no roxo do jogo. Barreira invisível na borda: ninguém cai.
--   * Fundo (`backdrop`, montado por CADA CLIENTE): o mirante e as 4 ilhas de duelo de verdade, pelo
--     mesmo código da partida (`WorldBuilder`), deslocados para a frente e para baixo. Só
--     ambientação: nada colide, nada faz sombra, e as peças de acabamento miúdas (que de longe não
--     aparecem) ficam de fora, para pesar menos no celular.
--
-- Coordenadas da ilha (x, z) no quadro do lobby: o jogador nasce olhando para o -Z, onde fica o fundo.

local Build = require(script.Parent.Build)
local PracaKit = require(script.Parent.Kits.Praca)
local TorreKit = require(script.Parent.Kits.Torre)
local WorldBuilder = require(script.Parent.WorldBuilder)
local MapConfig = require(script.Parent.Parent.Config.MapConfig)
local Theme = require(script.Parent.Parent.Config.Theme)

local LOBBY = MapConfig.Lobby
local P = Theme.Maps.Praca

local v2 = Vector2.new

local LobbyBuilder = {}

LobbyBuilder.FolderName = "LobbyWorld"
LobbyBuilder.BackdropName = "LobbyBackdrop"

local SIGNS = { -1, 1 }
local BARRIER: Build.PartOptions = { transparency = 1, query = false, shadow = false }
local NO_SHADOW: Build.PartOptions = { shadow = false }

-- Contorno da ilha: retângulo com os 4 cantos chanfrados (8 lados), no sentido horário.
local function outline(): { Vector2 }
	local hx, hz, c = LOBBY.IslandSize.X / 2, LOBBY.IslandSize.Y / 2, LOBBY.IslandChamfer
	return {
		v2(-hx + c, -hz),
		v2(hx - c, -hz),
		v2(hx, -hz + c),
		v2(hx, hz - c),
		v2(hx - c, hz),
		v2(-hx + c, hz),
		v2(-hx, hz - c),
		v2(-hx, -hz + c),
	}
end

-- A ilha do lobby, dentro de `parent`. `frame` = centro da ilha, no topo do piso.
function LobbyBuilder.island(parent: Instance, frame: CFrame): Folder
	local folder = Instance.new("Folder")
	folder.Name = LobbyBuilder.FolderName
	local hx, hz, c = LOBBY.IslandSize.X / 2, LOBBY.IslandSize.Y / 2, LOBBY.IslandChamfer
	local t = LOBBY.IslandThickness

	-- Piso de lajota: miolo, duas faixas laterais e os 4 chanfros
	Build.floorRect("Floor", frame, v2(-hx + c, -hz), v2(hx - c, hz), t, P.Piso, folder, 0, NO_SHADOW)
	for _, sx in SIGNS do
		local x0, x1 = sx * (hx - c), sx * hx
		Build.floorRect(
			"Floor",
			frame,
			v2(math.min(x0, x1), -hz + c),
			v2(math.max(x0, x1), hz - c),
			t,
			P.Piso,
			folder,
			0,
			NO_SHADOW
		)
		for _, sz in SIGNS do
			Build.floorTriangle(
				"Floor",
				frame,
				v2(sx * (hx - c), sz * (hz - c)),
				v2(sx * hx, sz * (hz - c)),
				v2(sx * (hx - c), sz * hz),
				t,
				P.Piso,
				folder,
				0,
				NO_SHADOW
			)
		end
	end
	-- Juntas das lajotas (acabamento): só onde o piso vai de borda a borda
	local step = LOBBY.TileStep
	for k = -math.floor((hx - c) / step), math.floor((hx - c) / step) do
		local x = k * step
		Build.floorRect(
			"Junta",
			frame,
			v2(x - 0.1, -hz),
			v2(x + 0.1, hz),
			0.03,
			P.PisoFaixa,
			folder,
			0.03,
			Build.Detail
		)
	end
	for k = -math.floor((hz - c) / step), math.floor((hz - c) / step) do
		local z = k * step
		Build.floorRect(
			"Junta",
			frame,
			v2(-hx, z - 0.1),
			v2(hx, z + 0.1),
			0.03,
			P.PisoFaixa,
			folder,
			0.03,
			Build.Detail
		)
	end

	-- Rocha embaixo, afunilando, sempre por dentro do contorno
	local top = -t
	for i, shrink in { 0.78, 0.55, 0.3 } do
		local height = 8 + i * 2
		Build.block(
			"Underside",
			Vector3.new((hx - c) * 2 * shrink + c, height, (hz - c) * 2 * shrink + c),
			frame * CFrame.new(0, top - height / 2, 0),
			if i == 1 then P.Terra else P.TerraEscura,
			folder,
			NO_SHADOW
		)
		top -= height
	end

	-- Mureta com pilares em volta e barreira invisível por fora (ninguém cai do lobby)
	local points = outline()
	for i, a in points do
		local b = points[i % #points + 1]
		-- O primeiro lado é o da vista: mureta baixa
		local rail = if i == 1 then LOBBY.FrontRail else LOBBY.Rail
		PracaKit.Mureta(folder, frame, a, b, rail, Vector2.zero)
		PracaKit.Pilar(folder, Build.pivot(frame, a), if i <= 2 then LOBBY.FrontRail else LOBBY.Rail)
		Build.wall("Barrier", frame, a, b, LOBBY.BarrierHeight, 1, P.Pedra, folder, 0, BARRIER)
	end

	-- Canteiros com árvore nos 4 cantos de dentro
	for _, sx in SIGNS do
		for _, sz in SIGNS do
			local at = v2(sx * (hx - c - 2), sz * (hz - c + 2))
			Build.floorRect("Canteiro", frame, at - v2(4, 4), at + v2(4, 4), 0.06, P.Grama, folder, 0.06, Build.Detail)
			PracaKit.ArvoreLowPoly(folder, Build.pivot(frame, at))
		end
	end

	-- Postes (o braço aponta para o meio da praça) e bancos virados para a vista (-Z)
	for _, sx in SIGNS do
		PracaKit.PosteDeLuz(folder, Build.pivot(frame, v2(sx * 16, -hz + 2), 180))
		PracaKit.PosteDeLuz(folder, Build.pivot(frame, v2(sx * 16, hz - 2), 0))
		PracaKit.BancoDePraca(folder, Build.pivot(frame, v2(sx * 12, 14), 180))
		-- Barracas de feira no fundo (atrás de quem nasce), com o toldo para a praça
		PracaKit.BarracaDeFeira(folder, Build.pivot(frame, v2(sx * 9, hz - 4), 180))
		-- Estandartes no roxo do jogo, dos dois lados da vista
		TorreKit.Estandarte(folder, Build.pivot(frame, v2(sx * (hx - c - 6), -hz + 2), 180))
	end
	folder.Parent = parent
	return folder
end

-- O fundo: o mundo da partida inteiro num Model sem pai, já deslocado para `frame` (o quadro da
-- ilha do lobby). `pause` roda entre as partes (um `task.wait`, para não travar ao entrar).
function LobbyBuilder.backdrop(frame: CFrame, pause: (() -> ())?): Model
	local world = WorldBuilder.build(pause)
	local model = Instance.new("Model")
	model.Name = LobbyBuilder.BackdropName
	local minFace = LOBBY.BackdropMinFace
	for _, item in world:GetDescendants() do
		if item:IsA("BasePart") then
			local s = item.Size
			local face = s.X * s.Y * s.Z / math.min(s.X, s.Y, s.Z) -- área da maior face
			local tiny = item:GetAttribute(Build.DetailAttribute) == true and face < minFace
			if item.Transparency >= 1 or tiny then
				item:Destroy()
			else
				item.CanCollide = false
				item.CanQuery = false
				item.CanTouch = false
				item.CastShadow = false
			end
		elseif item:IsA("BillboardGui") then
			item:Destroy()
		end
	end
	for _, child in world:GetChildren() do
		child.Parent = model
	end
	world:Destroy()
	-- O mundo é montado em volta da origem: basta somar o deslocamento em cada peça
	local shift = frame * CFrame.new(LOBBY.WorldOffset)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.CFrame = shift * item.CFrame
		end
	end
	return model
end

-- Servidor do lobby: monta a ilha no `container` (o Workspace), esconde a placa cinza do place e
-- leva o ponto de nascer para a ilha, olhando para a vista.
function LobbyBuilder.install(container: Instance): Folder
	WorldBuilder.applyLighting()
	local existing = container:FindFirstChild(LobbyBuilder.FolderName)
	if existing then
		existing:Destroy()
	end
	local frame = CFrame.new(LOBBY.Center)
	local folder = LobbyBuilder.island(container, frame)
	for _, child in container:GetChildren() do
		if child:IsA("SpawnLocation") then
			child.Transparency = 1
			child.CanCollide = false
			child.CanQuery = false
			child.CastShadow = false
			for _, decal in child:GetChildren() do
				if decal:IsA("Decal") then
					decal:Destroy()
				end
			end
			local at = frame * CFrame.new(0, child.Size.Y / 2, LOBBY.SpawnZ)
			child.CFrame = CFrame.lookAt(at.Position, at.Position + frame:VectorToWorldSpace(-Vector3.zAxis))
		elseif child:IsA("BasePart") and child.Name == "Baseplate" then
			child.Transparency = 1
			-- a placa do place tem uma textura quadriculada, que continua aparecendo com a peça invisível
			for _, item in child:GetChildren() do
				if item:IsA("Decal") then -- Texture também é Decal
					item.Transparency = 1
				end
			end
			child.CanCollide = false
			child.CanQuery = false
			child.CastShadow = false
		end
	end
	return folder
end

return LobbyBuilder
