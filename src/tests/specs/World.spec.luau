--!strict
-- Mundo da partida (FASES F10, GDD 6.5 e 15.3): mirante octogonal com piso de vidro, ilhas nos 4 lados
-- e regras do kit (KIT-MODULAR 1) que dá para conferir sem abrir o jogo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CharacterConfig = require(Shared.Config.CharacterConfig)
local IslandCommon = require(Shared.Maps.IslandCommon)
local MapConfig = require(Shared.Config.MapConfig)
local Strings = require(Shared.Config.Strings)
local ShieldPointRules = require(Shared.Match.ShieldPointRules)
local WorldBuilder = require(Shared.Maps.WorldBuilder)
local Zones = require(Shared.Maps.Zones)
local WorldLayout = require(Shared.Match.WorldLayout)

local WORLD = MapConfig.World

local function near(a: number, b: number, tolerance: number?): boolean
	return math.abs(a - b) <= (tolerance or 1e-3)
end

local function isRed(c: Color3): boolean
	local h, s, v = c:ToHSV()
	return (h < 0.03 or h > 0.95) and s > 0.6 and v > 0.5
end

-- Vértices de uma WedgePart (ângulo reto primeiro), no mundo.
local function wedgeCorners(w: WedgePart): (Vector3, Vector3, Vector3)
	local h, d = w.Size.Y / 2, w.Size.Z / 2
	return w.CFrame * Vector3.new(0, -h, d), w.CFrame * Vector3.new(0, h, d), w.CFrame * Vector3.new(0, -h, -d)
end

return function(t: any)
	t.test("uma ilha de cada lado do mirante: Porto N, Fábrica L, Praça S, Torre O", function()
		local expected = {
			map_porto = Vector3.new(0, 0, -1),
			map_fabrica = Vector3.new(1, 0, 0),
			map_praca = Vector3.new(0, 0, 1),
			map_torre = Vector3.new(-1, 0, 0),
		}
		t.eq(WorldLayout.islandCount(), 4)
		for i = 1, 4 do
			local id = WorldLayout.mapId(i)
			local center = WorldLayout.islandCenter(i)
			local flat = Vector3.new(center.X, 0, center.Z)
			t.ok(near(flat.Magnitude, WORLD.IslandDistance), `{id}: distância do mirante`)
			t.ok(flat.Unit:FuzzyEq(expected[id], 1e-3), `{id}: lado do mirante`)
		end
	end)

	t.test("bases à esquerda e à direita de quem olha do mirante (eixo X da ilha tangente)", function()
		for i = 1, 4 do
			local frame = WorldLayout.islandFrame(i)
			local outward = Vector3.new(frame.Position.X, 0, frame.Position.Z).Unit
			t.ok(near(frame.XVector:Dot(outward), 0), `ilha {i}: eixo base a base perpendicular ao mirante`)
			local a, b = WorldLayout.baseCenter(i, 1), WorldLayout.baseCenter(i, 2)
			t.ok(near((a - frame.Position).Magnitude, (b - frame.Position).Magnitude), `ilha {i}: bases simétricas`)
			t.ok(
				near((a - WorldLayout.miranteCenter()).Magnitude, (b - WorldLayout.miranteCenter()).Magnitude),
				`ilha {i}: as duas bases à mesma distância do mirante`
			)
		end
	end)

	t.test("nascer na base: dentro da própria ilha e a ~6 s do centro (GDD 15.1)", function()
		local speed = CharacterConfig.Movement.WalkSpeed
		for i = 1, 4 do
			for side = 1, 2 do
				for slot = 1, 2 do
					local spawn = WorldLayout.baseSpawn(i, side, slot)
					t.eq(WorldLayout.islandAt(spawn.Position), i, `ilha {i} lado {side} vaga {slot}`)
					local p = WorldLayout.islandFrame(i):PointToObjectSpace(spawn.Position)
					t.ok(math.abs(p.X) > WORLD.BodySize.X / 2, "nasce dentro da base, fora da área de duelo")
					local seconds = math.abs(p.X) / speed
					local target = MapConfig.General.BaseToCenterSeconds
					t.ok(seconds >= target * 0.75 and seconds <= target * 1.25, `{seconds} s até o centro`)
					local toCenter = (WorldLayout.islandCenter(i) - spawn.Position) * Vector3.new(1, 0, 1)
					t.ok(spawn.LookVector:Dot(toCenter.Unit) > 0.95, "olhando para o centro")
				end
			end
		end
	end)

	t.test("ilhas não se encostam nem ficam embaixo do mirante", function()
		local apothem = WorldLayout.miranteApothem()
		for i = 1, 4 do
			local frame = WorldLayout.islandFrame(i)
			-- cantos da ilha inteira (com as bases)
			local hx, hz = WorldLayout.islandHalfLength(), WORLD.BodySize.Y / 2
			for _, corner in { Vector3.new(hx, 0, hz), Vector3.new(-hx, 0, hz), Vector3.new(hx, 0, -hz) } do
				local world = frame * corner
				for j = 1, 4 do
					if j ~= i then
						t.ok(WorldLayout.islandAt(world) ~= j, `ilha {i} encosta na ilha {j}`)
					end
				end
			end
			local nearest = WORLD.IslandDistance - WORLD.BodySize.Y / 2
			t.ok(nearest > apothem + 10, `ilha {i}: vão entre o mirante e a ilha`)
		end
	end)

	t.test("da borda do mirante se vê a ilha olhando para baixo", function()
		local drop = WORLD.MiranteFloorY - WORLD.IslandFloorY
		local gap = WORLD.IslandDistance - WORLD.BodySize.Y / 2 - WorldLayout.miranteApothem()
		local angle = math.deg(math.atan2(drop, gap))
		t.ok(angle >= 25 and angle <= 60, `ângulo até a borda mais perto da ilha: {angle}°`)
	end)

	t.test("mirante octogonal: o vidro cobre o octógono inteiro sem sobrepor", function()
		local world = WorldBuilder.build()
		local found = world:FindFirstChild("Mirante")
		t.ok(found ~= nil, "pasta do mirante")
		local mirante = found :: Folder
		local side = WorldLayout.miranteSide()
		t.ok(near(side * (1 + math.sqrt(2)), WORLD.MiranteWidth), "lado do octógono")
		local center = WorldLayout.miranteCenter()
		local circumradius = side / (2 * math.sin(math.pi / 8))
		local half = side / 2
		local area = 0
		local glassCount = 0
		for _, part in mirante:GetChildren() do
			if part.Name == "Glass" then
				glassCount += 1
				t.ok(near((part :: BasePart).Transparency, MapConfig.Mirante.GlassTransparency), "vidro transparente")
				if part:IsA("WedgePart") then
					area += part.Size.Y * part.Size.Z / 2
					local right, a, b = wedgeCorners(part)
					local r = right - center
					t.ok(
						near(math.abs(r.X), half, 0.01) and near(math.abs(r.Z), half, 0.01),
						"ângulo reto no canto da placa"
					)
					for _, v in { a, b } do
						local flat = (v - center) * Vector3.new(1, 0, 1)
						t.ok(near(flat.Magnitude, circumradius, 0.01), "ponta do triângulo num vértice do octógono")
					end
					t.ok(
						near(right.Y, center.Y - WORLD.MiranteThickness / 2, 0.01),
						"triângulo deitado no nível do piso"
					)
				elseif part:IsA("Part") then
					area += part.Size.X * part.Size.Z
				end
			end
		end
		t.eq(glassCount, 9, "quadrado do centro + 4 painéis retos + 4 triângulos")
		local octagon = 2 * (1 + math.sqrt(2)) * side * side
		t.ok(near(area, octagon, 0.5), `área do piso {area} = octógono {octagon}`)
		world:Destroy()
	end)

	t.test("regras do kit: sem neon, sem vermelho e dentro do orçamento de peças", function()
		local world = WorldBuilder.build()
		for _, folder in world:GetChildren() do
			local count = 0
			for _, part in folder:GetDescendants() do
				if part:IsA("BasePart") then
					count += 1
					t.ok(part.Material ~= Enum.Material.Neon, `{folder.Name}.{part.Name} sem neon`)
					t.ok(not isRed(part.Color), `{folder.Name}.{part.Name} sem vermelho`)
				end
			end
			if folder.Name:match("^Island") then
				t.ok(count <= MapConfig.Kit.MaxPartsPerIsland, `{folder.Name}: {count} peças`)
			end
		end
		world:Destroy()
	end)

	t.test("cada ilha tem zonas com nome (Strings.Zones) e 2 pontos de escudo simétricos", function()
		local world = WorldBuilder.build()
		for i = 1, WorldLayout.islandCount() do
			local folder = world:FindFirstChild(`Island{i}`) :: Instance
			local frame = WorldLayout.islandFrame(i)
			local zones, bodyZones = 0, 0
			local pads: { Vector3 } = {}
			for _, item in folder:GetDescendants() do
				local zoneId = item:GetAttribute(IslandCommon.ZoneAttribute)
				if zoneId ~= nil then
					zones += 1
					t.ok(Strings.Zones[zoneId] ~= nil, `ilha {i}: zona "{zoneId}" tem nome em Strings.Zones`)
					if zoneId ~= "base" then
						bodyZones += 1
					end
				end
				if item.Name == "ShieldPoint" and item:IsA("Model") then
					table.insert(pads, frame:PointToObjectSpace(item:GetPivot().Position))
				end
			end
			t.ok(bodyZones >= 3, `ilha {i}: {bodyZones} zonas na área de duelo (mínimo 3)`)
			t.eq(#pads, MapConfig.General.ShieldPickupsPerMap, `ilha {i}: pontos de escudo`)
			if #pads == 2 then
				-- simétricos: espelhados (x, z) → (-x, z) ou girados (x, z) → (-x, -z)
				local a, b = pads[1], pads[2]
				t.ok(near(a.X, -b.X, 0.1) and near(math.abs(a.Z), math.abs(b.Z), 0.1), `ilha {i}: escudos simétricos`)
			end
		end
		world:Destroy()
	end)

	t.test("zona de um ponto: todo ponto de escudo e toda base caem numa zona com nome", function()
		local world = WorldBuilder.build()
		for i = 1, WorldLayout.islandCount() do
			local folder = world:FindFirstChild(`Island{i}`) :: Instance
			local parts = folder:GetDescendants()
			for _, item in parts do
				if item.Name == "ShieldPoint" and item:IsA("Model") then
					local zoneId, side = Zones.find(item:GetPivot().Position + Vector3.new(0, 1, 0), parts)
					t.ok(zoneId ~= nil, `ilha {i}: ponto de escudo dentro de uma zona`)
					t.ok(Zones.name(zoneId, side) ~= nil, `ilha {i}: zona "{zoneId}" com nome`)
				end
			end
			for side = 1, 2 do
				local spawn = WorldLayout.baseSpawn(i, side, 1).Position
				local zoneId = Zones.find(spawn, parts)
				t.eq(zoneId, "base", `ilha {i} lado {side}: nascer fica na zona Base`)
			end
			-- fora da ilha não há zona
			t.eq(Zones.find(WorldLayout.miranteCenter(), parts), nil, `ilha {i}: mirante sem zona`)
		end
		world:Destroy()
	end)

	t.test("nome da zona: com e sem lado; zona desconhecida não tem nome", function()
		t.eq(Zones.name("muro", "east"), `{Strings.Zones.muro} {Strings.ZoneSides.east}`)
		t.eq(Zones.name("guindaste", nil), Strings.Zones.guindaste)
		t.eq(Zones.name("nao_existe", "west"), nil)
		t.eq(Zones.name(nil, nil), nil)
	end)

	t.test("ponto de escudo: só vivo, com escudo incompleto, em cima e com o ponto aceso", function()
		local max = CharacterConfig.Health.MaxShield
		t.ok(ShieldPointRules.canPickup(true, 0, true), "sem escudo pega")
		t.ok(ShieldPointRules.canPickup(true, max - 1, true), "escudo incompleto pega")
		t.ok(not ShieldPointRules.canPickup(true, max, true), "escudo cheio não gasta o ponto")
		t.ok(not ShieldPointRules.canPickup(false, 0, true), "derrubado não pega")
		t.ok(not ShieldPointRules.canPickup(true, 0, false), "ponto apagado não dá escudo")

		local pad = Vector3.new(10, 0, 20)
		local radius, height = MapConfig.General.ShieldPickupRadius, MapConfig.General.ShieldPickupHeight
		t.ok(ShieldPointRules.inReach(pad, pad + Vector3.new(0, 3, 0)), "em cima")
		t.ok(ShieldPointRules.inReach(pad, pad + Vector3.new(radius, 3, 0)), "na beira")
		t.ok(not ShieldPointRules.inReach(pad, pad + Vector3.new(radius + 0.5, 3, 0)), "ao lado")
		t.ok(not ShieldPointRules.inReach(pad, pad + Vector3.new(0, height + 1, 0)), "muito acima (outro nível)")
		t.ok(not ShieldPointRules.inReach(pad, pad + Vector3.new(0, -1, 0)), "embaixo")
	end)

	t.test("ponto de escudo: reacende em 20 s (nem um instante antes)", function()
		local seconds = MapConfig.General.ShieldPickupRespawnSeconds
		t.eq(seconds, 20)
		t.ok(ShieldPointRules.isActive(nil, 0), "nunca usado: aceso")
		local readyAt = ShieldPointRules.readyAfter(100)
		t.eq(readyAt, 100 + seconds)
		t.ok(not ShieldPointRules.isActive(readyAt, 100 + seconds - 0.01), "ainda apagado")
		t.ok(ShieldPointRules.isActive(readyAt, 100 + seconds), "aceso de novo")
	end)

	t.test("peças de acabamento não colidem nem bloqueiam tiro", function()
		local world = WorldBuilder.build()
		for _, part in world:GetDescendants() do
			if part:IsA("BasePart") and part:GetAttribute(WorldBuilder.DetailAttribute) then
				t.ok(not part.CanCollide and not part.CanQuery, `{part:GetFullName()} é acabamento`)
			end
		end
		world:Destroy()
	end)

	t.test("o mundo salvo no place da Partida está em dia com o código", function()
		local saved = workspace:FindFirstChild(WorldBuilder.FolderName)
		if saved == nil then
			return -- lobby e tutorial não têm o mundo da partida
		end
		t.ok(
			saved:GetAttribute(WorldBuilder.RebuiltAttribute) ~= true,
			"a cópia salva estava velha: montar de novo (README, 'Mapa salvo no place') e salvar o place"
		)
	end)
end
