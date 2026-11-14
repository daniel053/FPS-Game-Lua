--!strict
-- Mundo da partida (FASES F10, GDD 6.5 e 15.3): mirante octogonal com piso de vidro, ilhas nos 4 lados
-- e regras do kit (KIT-MODULAR 1) que dá para conferir sem abrir o jogo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CharacterConfig = require(Shared.Config.CharacterConfig)
local MapConfig = require(Shared.Config.MapConfig)
local WorldBuilder = require(Shared.Maps.WorldBuilder)
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
end
