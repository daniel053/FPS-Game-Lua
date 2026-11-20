--!strict
-- Modelos LOW POLY detalhados das 18 armas e do Bastão, peça por peça (caixas, cilindros e cunhas),
-- a pedido do dono do projeto na F7 (referências docs/referencias/ref-menus-armas.webp e
-- ref-tatico-atirador.webp). Provisórios até a arte final da F10. Só cliente.
-- Usados pelo WeaponShapes (vitrines da interface e arma em primeira pessoa).
--
-- Convenção: o cano aponta para -Z, Y para cima, X para o lado. Cada modelo devolve onde fica a boca
-- do cano, a mão esquerda (nil = uma mão só) e a empunhadura (mão direita).
-- Pentes curvos inclinam a base PARA A FRENTE (na direção do cano) e encaixam embaixo do encaixe.

-- `mag` = peça do pente (sai e entra na animação de recarga em primeira pessoa).
export type PartSpec = {
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	cylinder: boolean?,
	wedge: boolean?,
	mag: boolean?,
}

export type Look = { body: Color3, dark: Color3, light: Color3, accent: Color3, metal: Color3, lens: Color3 }

type Parts = { PartSpec }

export type Built = { parts: Parts, muzzle: Vector3, leftHand: Vector3?, grip: Vector3 }

local WeaponModels = {}

local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- o cilindro do Roblox fica deitado no eixo X
local ALONG_Y = CFrame.Angles(0, 0, math.rad(90))

-- Peças --------------------------------------------------------------------------------------------

-- Caixa. rx = inclinação em graus em volta de X (positivo = a parte de baixo vai para a frente).
local function B(
	p: Parts,
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	color: Color3,
	rx: number?
)
	local rot = if rx then CFrame.Angles(math.rad(rx), 0, 0) else CFrame.identity
	table.insert(p, { size = Vector3.new(sx, sy, sz), cframe = CFrame.new(x, y, z) * rot, color = color })
end

-- Cilindro ao longo de Z (padrão), X ou Y.
local function C(p: Parts, length: number, d: number, x: number, y: number, z: number, color: Color3, axis: string?)
	local rot = if axis == "X" then CFrame.identity elseif axis == "Y" then ALONG_Y else ALONG_Z
	table.insert(p, {
		size = Vector3.new(length, d, d),
		cframe = CFrame.new(x, y, z) * rot,
		color = color,
		cylinder = true,
	})
end

-- Cunha (rampa). Sem giro: a face reta fica atrás (+Z) e a rampa desce para a frente.
-- `ry` = 180 vira a rampa para trás.
local function W(
	p: Parts,
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	color: Color3,
	ry: number?
)
	local rot = if ry then CFrame.Angles(0, math.rad(ry), 0) else CFrame.identity
	table.insert(p, { size = Vector3.new(sx, sy, sz), cframe = CFrame.new(x, y, z) * rot, color = color, wedge = true })
end

-- Conjuntos comuns ----------------------------------------------------------------------------------

-- Marca como pente as peças acrescentadas desde `from` (índice em `p`).
local function markMag(p: Parts, from: number)
	for i = from, #p do
		p[i].mag = true
	end
end

-- Empunhadura de pistola (inclinada para trás), guarda-mato e gatilho. z = centro da empunhadura.
local function pistolGrip(p: Parts, c: Look, z: number, y: number?, cap: Color3?)
	local gy = y or -0.21
	B(p, 0.15, 0.36, 0.17, 0, gy, z, c.dark, -18)
	B(p, 0.16, 0.05, 0.19, 0, gy - 0.18, z + 0.06, cap or c.dark, -18)
	B(p, 0.155, 0.22, 0.03, 0, gy, z - 0.07, c.light, -18) -- textura da frente
	B(p, 0.04, 0.03, 0.24, 0, gy + 0.06, z - 0.15, c.dark) -- guarda-mato
	B(p, 0.04, 0.09, 0.03, 0, gy + 0.11, z - 0.27, c.dark)
	B(p, 0.03, 0.09, 0.03, 0, gy + 0.13, z - 0.17, c.metal) -- gatilho
end

-- Trilho picatinny: barra com dentes.
local function rail(p: Parts, zBack: number, zFront: number, y: number, color: Color3)
	local length = zBack - zFront
	B(p, 0.12, 0.05, length, 0, y, (zBack + zFront) / 2, color)
	for i = 0, math.floor(length / 0.11) - 1 do
		B(p, 0.15, 0.03, 0.05, 0, y + 0.035, zBack - 0.06 - i * 0.11, color)
	end
end

-- Freio de boca: cilindro com duas janelas claras. Devolve a ponta.
local function brake(p: Parts, c: Look, z: number, y: number, d: number, length: number): Vector3
	C(p, length, d, 0, y, z, c.dark)
	for _, dz in { -length * 0.2, length * 0.2 } do
		B(p, d + 0.01, d * 0.28, length * 0.16, 0, y, z + dz, c.metal)
	end
	return Vector3.new(0, y, z - length / 2 - 0.02)
end

-- Fendas de ventilação em fila (guarda-mão).
local function slots(p: Parts, zs: { number }, y: number, width: number, h: number, length: number, color: Color3)
	for _, z in zs do
		B(p, width + 0.01, h, length, 0, y, z, color)
	end
end

-- Pente curvo: o topo encaixa em (yTop, z); a base curva para a frente.
local function curvedMag(p: Parts, c: Look, z: number, yTop: number, tone: Color3?)
	local first = #p + 1
	local color = tone or c.dark
	B(p, 0.15, 0.3, 0.2, 0, yTop - 0.14, z, color, 6)
	B(p, 0.15, 0.24, 0.2, 0, yTop - 0.4, z - 0.06, color, 18)
	B(p, 0.16, 0.035, 0.21, 0, yTop - 0.11, z, c.metal, 6) -- friso
	B(p, 0.17, 0.04, 0.22, 0, yTop - 0.53, z - 0.1, c.metal, 18) -- base
	markMag(p, first)
end

-- Pente reto (levemente inclinado para a frente).
local function straightMag(p: Parts, c: Look, z: number, yTop: number, h: number, tone: Color3?)
	local first = #p + 1
	B(p, 0.14, h, 0.19, 0, yTop - h / 2, z - 0.02, tone or c.dark, 4)
	B(p, 0.16, 0.04, 0.21, 0, yTop - h, z - 0.05, c.metal, 4)
	markMag(p, first)
end

-- Luneta: tubo, objetiva e ocular com lentes, torres e suportes até o trilho.
local function scope(p: Parts, c: Look, z: number, y: number, length: number, d: number, railY: number)
	C(p, length, d, 0, y, z, c.dark)
	C(p, length * 0.3, d * 1.9, 0, y, z - length / 2, c.dark) -- objetiva
	C(p, 0.02, d * 1.55, 0, y, z - length / 2 - length * 0.15, c.lens)
	C(p, length * 0.24, d * 1.55, 0, y, z + length / 2, c.dark) -- ocular
	C(p, 0.02, d * 1.15, 0, y, z + length / 2 + length * 0.12, c.lens)
	C(p, d * 0.9, d * 1.2, 0, y, z, c.dark) -- corpo das torres
	C(p, d * 0.7, d, 0, y + d * 0.9, z, c.metal, "Y")
	C(p, d * 0.7, d, d * 0.9, y, z, c.metal, "X")
	for _, dz in { -length * 0.3, length * 0.3 } do
		C(p, 0.08, d * 1.35, 0, y, z + dz, c.dark) -- anel
		B(p, 0.12, y - railY, 0.08, 0, (y + railY) / 2, z + dz, c.dark) -- suporte
	end
end

-- Mira holográfica com vidro colorido.
local function holo(p: Parts, c: Look, z: number, railY: number)
	B(p, 0.17, 0.06, 0.26, 0, railY + 0.06, z, c.dark)
	B(p, 0.23, 0.24, 0.2, 0, railY + 0.2, z, c.dark)
	B(p, 0.25, 0.04, 0.26, 0, railY + 0.34, z, c.dark)
	B(p, 0.17, 0.16, 0.02, 0, railY + 0.2, z - 0.105, c.lens)
	B(p, 0.17, 0.16, 0.02, 0, railY + 0.2, z + 0.105, c.lens)
	B(p, 0.235, 0.13, 0.12, 0, railY + 0.22, z, c.lens)
	C(p, 0.06, 0.07, 0.13, railY + 0.12, z, c.metal, "X")
end

-- Mira pontual pequena (red dot).
local function dot(p: Parts, c: Look, z: number, railY: number)
	B(p, 0.13, 0.05, 0.16, 0, railY + 0.05, z, c.dark)
	C(p, 0.18, 0.14, 0, railY + 0.14, z, c.dark)
	C(p, 0.02, 0.1, 0, railY + 0.14, z - 0.095, c.lens)
end

-- Alças de mira de ferro (traseira e massa).
local function irons(p: Parts, c: Look, zRear: number, zFront: number, railY: number)
	B(p, 0.12, 0.12, 0.06, 0, railY + 0.08, zRear, c.dark)
	B(p, 0.14, 0.08, 0.1, 0, railY + 0.05, zFront, c.dark)
	B(p, 0.05, 0.18, 0.05, 0, railY + 0.17, zFront, c.dark)
end

-- Coronha regulável estilo AR: tubo + coronha com vão + soleira.
local function arStock(p: Parts, c: Look, color: Color3)
	C(p, 0.42, 0.13, 0, 0.17, 0.5, c.dark)
	B(p, 0.2, 0.13, 0.5, 0, 0.2, 0.86, color)
	B(p, 0.2, 0.4, 0.09, 0, 0.0, 1.07, color)
	B(p, 0.2, 0.09, 0.5, 0, -0.03, 0.86, color, 34)
	B(p, 0.25, 0.48, 0.07, 0, 0.02, 1.15, c.dark)
end

-- Ferrolho de pistola (slide) com serrilhado, janela de ejeção e miras. Devolve a boca do cano.
local function pistolSlide(p: Parts, c: Look, length: number, color: Color3): Vector3
	local zc = 0.16 - length / 2
	B(p, 0.2, 0.17, length, 0, 0.22, zc, color)
	B(p, 0.19, 0.12, length * 0.88, 0, 0.08, zc - length * 0.04, c.dark) -- armação
	for i = 0, 3 do
		B(p, 0.205, 0.11, 0.02, 0, 0.22, 0.12 - i * 0.045, c.dark) -- serrilhado
	end
	B(p, 0.205, 0.06, 0.14, 0, 0.27, -0.12, c.metal) -- janela de ejeção
	B(p, 0.1, 0.05, 0.05, 0, 0.33, 0.12, c.dark) -- alça
	B(p, 0.04, 0.05, 0.04, 0, 0.33, 0.2 - length, c.dark) -- massa
	C(p, 0.06, 0.09, 0, 0.23, 0.17 - length, c.dark)
	return Vector3.new(0, 0.23, 0.13 - length)
end

-- Empunhadura de pistola (uma mão), com guarda-mato e base do pente. `revolver` = sem pente (a base
-- é só o fim do cabo).
local function pistolLower(p: Parts, c: Look, cap: Color3?, revolver: boolean?)
	B(p, 0.17, 0.42, 0.22, 0, -0.14, 0.08, c.dark, -15)
	B(p, 0.175, 0.3, 0.14, 0, -0.12, 0.06, c.light, -15) -- textura
	local first = #p + 1
	if not revolver then
		B(p, 0.13, 0.36, 0.16, 0, -0.17, 0.09, c.metal, -15) -- pente (escondido no cabo até sair)
	end
	B(p, 0.18, 0.05, 0.24, 0, -0.36, 0.14, cap or c.dark, -15) -- base do pente
	if not revolver then
		markMag(p, first)
	end
	B(p, 0.04, 0.03, 0.22, 0, -0.03, -0.12, c.dark) -- guarda-mato
	B(p, 0.04, 0.1, 0.03, 0, 0.01, -0.23, c.dark)
	B(p, 0.03, 0.08, 0.03, 0, 0.02, -0.08, c.metal) -- gatilho
end

-- Modelos ------------------------------------------------------------------------------------------

type Builder = (c: Look, p: Parts) -> (Vector3, Vector3?, Vector3)

local PISTOL_GRIP = Vector3.new(0, -0.16, 0.08)
local RIFLE_GRIP = Vector3.new(0, -0.2, 0.27)

local MODELS: { [string]: Builder } = {
	-- PISTOLAS ---------------------------------------------------------------------------------
	-- Bolinha: a pistola de começo, ferrolho grafite com faixa roxa.
	weapon_bolinha = function(c, p)
		local muzzle = pistolSlide(p, c, 0.8, c.body)
		B(p, 0.205, 0.035, 0.62, 0, 0.17, -0.24, c.accent)
		B(p, 0.045, 0.03, 0.045, 0, 0.36, -0.6, c.accent) -- ponto da massa
		pistolLower(p, c)
		return muzzle, nil, PISTOL_GRIP
	end,
	-- Chumbinho: ferrolho claro e curto, boca larga de escopeta.
	weapon_chumbinho = function(c, p)
		pistolSlide(p, c, 0.66, c.body)
		C(p, 0.3, 0.22, 0, 0.21, -0.62, c.dark) -- boca larga
		C(p, 0.02, 0.15, 0, 0.21, -0.775, Color3.new(0.06, 0.06, 0.08))
		C(p, 0.05, 0.24, 0, 0.21, -0.52, c.accent)
		pistolLower(p, c)
		return Vector3.new(0, 0.21, -0.8), nil, PISTOL_GRIP
	end,
	-- Zumbido: automática com faixas laranja, compensador e pente estendido.
	weapon_zumbido = function(c, p)
		pistolSlide(p, c, 0.78, c.body)
		for _, z in { -0.3, -0.42 } do
			B(p, 0.21, 0.175, 0.045, 0, 0.22, z, c.accent)
		end
		B(p, 0.2, 0.17, 0.14, 0, 0.22, -0.72, c.dark) -- compensador
		B(p, 0.205, 0.05, 0.03, 0, 0.27, -0.7, c.accent)
		pistolLower(p, c)
		local mag = #p + 1
		B(p, 0.15, 0.32, 0.18, 0, -0.52, 0.19, c.dark, -15) -- pente estendido
		B(p, 0.17, 0.05, 0.2, 0, -0.68, 0.23, c.accent, -15)
		markMag(p, mag)
		return Vector3.new(0, 0.22, -0.8), nil, PISTOL_GRIP
	end,
	-- Precisa: ferrolho longo cinza com linha ciano e silenciador.
	weapon_precisa = function(c, p)
		pistolSlide(p, c, 0.86, c.body)
		B(p, 0.205, 0.03, 0.7, 0, 0.16, -0.27, c.accent)
		C(p, 0.5, 0.15, 0, 0.23, -0.98, c.dark) -- silenciador
		for _, z in { -0.76, -1.2 } do
			C(p, 0.04, 0.16, 0, 0.23, z, c.metal)
		end
		pistolLower(p, c)
		return Vector3.new(0, 0.23, -1.24), nil, PISTOL_GRIP
	end,
	-- Tambor: revólver prateado com tambor, cano longo e cão.
	weapon_tambor = function(c, p)
		B(p, 0.18, 0.22, 0.42, 0, 0.16, -0.02, c.body) -- armação
		C(p, 0.3, 0.32, 0, 0.15, -0.1, c.metal) -- tambor
		for _, y in { 0.06, 0.24 } do
			B(p, 0.33, 0.03, 0.22, 0, y, -0.1, c.dark) -- canaletas
		end
		B(p, 0.13, 0.13, 0.62, 0, 0.24, -0.56, c.body) -- cano
		B(p, 0.11, 0.08, 0.52, 0, 0.14, -0.52, c.dark) -- ressalto de baixo
		B(p, 0.135, 0.03, 0.62, 0, 0.3, -0.56, c.accent) -- costela de cima
		B(p, 0.04, 0.06, 0.05, 0, 0.33, -0.83, c.dark) -- massa
		B(p, 0.05, 0.1, 0.07, 0, 0.3, 0.2, c.dark) -- cão
		pistolLower(p, c, c.accent, true)
		return Vector3.new(0, 0.24, -0.88), nil, PISTOL_GRIP
	end,

	-- SUBMETRALHADORAS -------------------------------------------------------------------------
	-- Ferrão: compacta, coronha dobrável, empunhadura vertical e detalhes rosa.
	weapon_ferrao = function(c, p)
		B(p, 0.24, 0.28, 0.86, 0, 0.14, -0.33, c.body) -- receptor
		B(p, 0.245, 0.05, 0.86, 0, 0.29, -0.33, c.accent) -- faixa de cima
		B(p, 0.245, 0.06, 0.16, 0, 0.18, -0.12, c.metal) -- janela de ejeção
		rail(p, 0.05, -0.7, 0.33, c.dark)
		dot(p, c, -0.2, 0.33)
		for _, x in { -0.09, 0.09 } do
			B(p, 0.04, 0.04, 0.5, x, 0.16, 0.36, c.dark) -- coronha dobrável
		end
		B(p, 0.24, 0.24, 0.05, 0, 0.12, 0.62, c.dark)
		pistolGrip(p, c, 0.06, -0.17)
		B(p, 0.14, 0.18, 0.2, 0, -0.06, -0.33, c.body) -- encaixe
		straightMag(p, c, -0.33, -0.14, 0.42)
		B(p, 0.11, 0.28, 0.12, 0, -0.14, -0.66, c.dark, 8) -- empunhadura vertical
		C(p, 0.3, 0.1, 0, 0.16, -0.9, c.dark)
		C(p, 0.12, 0.16, 0, 0.16, -1.08, c.accent) -- ponta rosa
		return Vector3.new(0, 0.16, -1.15), Vector3.new(0, -0.05, -0.66), Vector3.new(0, -0.16, 0.06)
	end,
	-- Vespa: equilibrada, listras amarelas, silenciador integrado e coronha de tubo.
	weapon_vespa = function(c, p)
		B(p, 0.24, 0.26, 1.0, 0, 0.15, -0.36, c.body)
		for _, z in { -0.08, -0.36, -0.64 } do
			B(p, 0.25, 0.27, 0.06, 0, 0.15, z, c.accent) -- listras
		end
		rail(p, 0.1, -0.8, 0.3, c.dark)
		irons(p, c, 0.06, -0.78, 0.3)
		C(p, 0.5, 0.17, 0, 0.16, -1.1, c.dark) -- silenciador integrado
		C(p, 0.04, 0.18, 0, 0.16, -0.88, c.accent)
		C(p, 0.4, 0.1, 0, 0.18, 0.34, c.dark) -- tubo
		B(p, 0.22, 0.3, 0.06, 0, 0.12, 0.56, c.dark)
		pistolGrip(p, c, 0.06, -0.17)
		B(p, 0.14, 0.16, 0.2, 0, -0.05, -0.36, c.body)
		straightMag(p, c, -0.36, -0.12, 0.44, c.dark)
		B(p, 0.16, 0.05, 0.21, 0, -0.38, -0.39, c.accent, 4) -- listra do pente
		markMag(p, #p)
		return Vector3.new(0, 0.16, -1.37), Vector3.new(0, -0.03, -0.72), Vector3.new(0, -0.16, 0.06)
	end,

	-- ESCOPETAS --------------------------------------------------------------------------------
	-- Balde: escopeta de bomba com tubo de cartuchos e porta-cartuchos laranja.
	weapon_balde = function(c, p)
		B(p, 0.2, 0.26, 0.5, 0, 0.06, 0.62, c.body) -- coronha
		W(p, 0.2, 0.12, 0.5, 0, -0.13, 0.62, c.body, 180)
		B(p, 0.24, 0.42, 0.07, 0, 0.0, 0.9, c.dark) -- soleira
		B(p, 0.24, 0.26, 0.6, 0, 0.12, 0.08, c.body) -- receptor
		B(p, 0.245, 0.08, 0.2, 0, 0.16, 0.08, c.metal) -- janela
		B(p, 0.03, 0.14, 0.44, 0.13, 0.12, 0.1, c.dark) -- porta-cartuchos
		for i = 0, 3 do
			C(p, 0.18, 0.075, 0.15, 0.12, 0.27 - i * 0.11, c.accent, "Y")
		end
		pistolGrip(p, c, 0.32, -0.17)
		C(p, 1.3, 0.13, 0, 0.24, -0.86, c.dark) -- cano
		C(p, 1.0, 0.11, 0, 0.1, -0.74, c.dark) -- tubo de cartuchos
		B(p, 0.2, 0.17, 0.44, 0, 0.1, -0.84, c.light) -- bomba
		for _, z in { -0.7, -0.8, -0.9, -1.0 } do
			B(p, 0.205, 0.03, 0.03, 0, 0.1, z, c.dark)
		end
		C(p, 0.04, 0.05, 0, 0.32, -1.48, c.accent, "Y") -- conta de mira
		return Vector3.new(0, 0.24, -1.52), Vector3.new(0, -0.02, -0.84), RIFLE_GRIP + Vector3.new(0, 0.04, 0.05)
	end,
	-- Varredor: automática verde com carregador de tambor e cano ventilado.
	weapon_varredor = function(c, p)
		B(p, 0.26, 0.3, 0.9, 0, 0.12, 0.05, c.body)
		B(p, 0.265, 0.06, 0.9, 0, 0.29, 0.05, c.dark)
		rail(p, 0.4, -0.3, 0.32, c.dark)
		dot(p, c, 0.0, 0.32)
		B(p, 0.22, 0.26, 0.45, 0, 0.1, 0.72, c.body) -- coronha
		B(p, 0.24, 0.36, 0.07, 0, 0.06, 0.97, c.dark)
		pistolGrip(p, c, 0.3, -0.17)
		local mag = #p + 1
		C(p, 0.22, 0.52, 0, -0.26, -0.2, c.dark, "X") -- carregador de tambor
		C(p, 0.24, 0.22, 0, -0.26, -0.2, c.accent, "X")
		markMag(p, mag)
		B(p, 0.22, 0.2, 0.62, 0, 0.17, -0.7, c.dark) -- capa do cano
		slots(p, { -0.55, -0.7, -0.85 }, 0.17, 0.22, 0.08, 0.08, c.metal)
		B(p, 0.11, 0.24, 0.12, 0, -0.06, -0.72, c.dark, 8) -- empunhadura da frente
		local muzzle = brake(p, c, -1.12, 0.19, 0.17, 0.22)
		C(p, 0.22, 0.12, 0, 0.19, -0.95, c.dark)
		return muzzle, Vector3.new(0, -0.06, -0.72), RIFLE_GRIP + Vector3.new(0, 0.04, 0.03)
	end,

	-- FUZIS LEVES ------------------------------------------------------------------------------
	-- Tático: AR compacto cor de areia e preto, mira holográfica laranja, pente curvo, freio de boca.
	weapon_tatico = function(c, p)
		local tan, black = c.body, c.dark
		arStock(p, c, tan)
		B(p, 0.2, 0.2, 0.55, 0, 0.0, 0.05, tan) -- receptor inferior
		B(p, 0.2, 0.16, 0.24, 0, -0.15, -0.18, tan) -- encaixe do pente
		B(p, 0.22, 0.18, 0.8, 0, 0.19, -0.05, black) -- receptor superior
		B(p, 0.225, 0.07, 0.2, 0, 0.17, 0.02, c.metal) -- janela de ejeção
		C(p, 0.12, 0.08, 0.11, 0.24, 0.26, black) -- assistente
		B(p, 0.14, 0.04, 0.08, 0, 0.29, 0.33, black) -- manobra
		pistolGrip(p, c, 0.27, -0.21, tan)
		curvedMag(p, c, -0.18, -0.23)
		B(p, 0.27, 0.27, 0.78, 0, 0.19, -0.84, tan) -- guarda-mão
		slots(p, { -0.6, -0.74, -0.88 }, 0.25, 0.27, 0.05, 0.09, black)
		B(p, 0.28, 0.13, 0.42, 0, 0.11, -1.0, black) -- painel da frente
		slots(p, { -0.88, -1.0, -1.12 }, 0.11, 0.28, 0.05, 0.05, c.metal)
		W(p, 0.27, 0.27, 0.08, 0, 0.19, -1.27, tan)
		rail(p, 0.38, -1.18, 0.33, black)
		holo(p, c, -0.12, 0.33)
		irons(p, c, 0.3, -1.13, 0.33)
		C(p, 0.42, 0.1, 0, 0.2, -1.5, black)
		local muzzle = brake(p, c, -1.8, 0.2, 0.16, 0.24)
		return muzzle, Vector3.new(0, 0.0, -0.95), RIFLE_GRIP
	end,
	-- Atirador: DMR verde-oliva comprido, coronha esqueletada, luneta com lente azul, cano longo.
	weapon_atirador = function(c, p)
		local green, black = c.body, c.dark
		B(p, 0.25, 0.46, 0.07, 0, 0.02, 1.22, black) -- soleira
		B(p, 0.22, 0.13, 0.52, 0, 0.18, 0.95, green)
		B(p, 0.22, 0.12, 0.52, 0, -0.14, 0.95, green)
		B(p, 0.22, 0.32, 0.1, 0, 0.02, 0.72, green)
		B(p, 0.18, 0.06, 0.3, 0, 0.27, 1.0, black) -- apoio do rosto
		B(p, 0.24, 0.24, 0.9, 0, 0.09, 0.2, green) -- chassi
		B(p, 0.22, 0.16, 0.72, 0, 0.26, -0.05, black) -- receptor
		B(p, 0.225, 0.06, 0.18, 0, 0.24, 0.08, c.metal) -- ferrolho
		B(p, 0.21, 0.18, 0.24, 0, -0.11, -0.18, green) -- encaixe do pente
		pistolGrip(p, c, 0.27, -0.21)
		straightMag(p, c, -0.18, -0.2, 0.36)
		B(p, 0.26, 0.24, 1.1, 0, 0.18, -0.92, green) -- guarda-mão
		slots(p, { -0.66, -0.94, -1.22 }, 0.2, 0.26, 0.05, 0.2, black)
		W(p, 0.26, 0.24, 0.1, 0, 0.18, -1.52, green)
		rail(p, 0.38, -1.45, 0.325, black)
		scope(p, c, -0.25, 0.6, 1.0, 0.13, 0.35)
		C(p, 0.9, 0.1, 0, 0.2, -1.95, black)
		local muzzle = brake(p, c, -2.5, 0.2, 0.16, 0.26)
		return muzzle, Vector3.new(0, 0.0, -1.0), RIFLE_GRIP
	end,

	-- FUZIS ------------------------------------------------------------------------------------
	-- Rajada: AR preto com faixas laranja, alça de transporte e massa de mira alta.
	weapon_rajada = function(c, p)
		local body, black = c.body, c.dark
		arStock(p, c, black)
		B(p, 0.2, 0.2, 0.55, 0, 0.0, 0.05, body)
		B(p, 0.2, 0.16, 0.24, 0, -0.15, -0.18, body)
		B(p, 0.22, 0.18, 0.8, 0, 0.19, -0.05, black)
		B(p, 0.225, 0.07, 0.2, 0, 0.17, 0.02, c.metal)
		B(p, 0.14, 0.04, 0.08, 0, 0.29, 0.33, black)
		B(p, 0.1, 0.12, 0.5, 0, 0.4, -0.05, black) -- alça de transporte
		B(p, 0.1, 0.12, 0.06, 0, 0.32, 0.18, black)
		B(p, 0.1, 0.12, 0.06, 0, 0.32, -0.28, black)
		pistolGrip(p, c, 0.27, -0.21)
		curvedMag(p, c, -0.18, -0.23)
		C(p, 0.8, 0.26, 0, 0.19, -0.85, body) -- guarda-mão redondo
		for _, z in { -0.62, -0.78, -0.94, -1.1 } do
			C(p, 0.05, 0.27, 0, 0.19, z, c.accent) -- faixas laranja
		end
		B(p, 0.06, 0.2, 0.06, 0, 0.42, -1.3, black) -- massa alta
		B(p, 0.12, 0.12, 0.08, 0, 0.3, -1.3, black)
		C(p, 0.5, 0.1, 0, 0.2, -1.45, black)
		local muzzle = brake(p, c, -1.8, 0.2, 0.14, 0.2)
		return muzzle, Vector3.new(0, 0.03, -0.9), RIFLE_GRIP
	end,
	-- Trovão: fuzil pesado azul, receptor grande, pente reto, freio de boca largo.
	weapon_trovao = function(c, p)
		local blue, black = c.body, c.dark
		B(p, 0.24, 0.44, 0.08, 0, 0.04, 1.12, black) -- soleira
		B(p, 0.22, 0.3, 0.5, 0, 0.1, 0.84, blue) -- coronha
		B(p, 0.223, 0.12, 0.3, 0, 0.06, 0.84, black) -- vão
		B(p, 0.26, 0.28, 1.0, 0, 0.12, 0.05, blue) -- receptor
		B(p, 0.265, 0.06, 1.0, 0, 0.0, 0.05, black)
		B(p, 0.265, 0.07, 0.22, 0, 0.18, 0.15, c.metal)
		B(p, 0.27, 0.05, 0.6, 0, 0.27, -0.05, c.accent) -- faixa
		pistolGrip(p, c, 0.3, -0.18)
		B(p, 0.2, 0.14, 0.24, 0, -0.07, -0.18, blue)
		straightMag(p, c, -0.18, -0.14, 0.4)
		B(p, 0.25, 0.22, 0.7, 0, 0.15, -0.85, black) -- guarda-mão
		slots(p, { -0.65, -0.85, -1.05 }, 0.15, 0.25, 0.06, 0.12, c.metal)
		rail(p, 0.45, -1.15, 0.31, black)
		dot(p, c, -0.15, 0.31)
		C(p, 0.4, 0.11, 0, 0.18, -1.38, black)
		B(p, 0.22, 0.18, 0.3, 0, 0.18, -1.7, black) -- freio largo
		slots(p, { -1.62, -1.72 }, 0.18, 0.22, 0.08, 0.04, c.metal)
		return Vector3.new(0, 0.18, -1.86), Vector3.new(0, 0.02, -0.85), RIFLE_GRIP + Vector3.new(0, 0.03, 0.03)
	end,

	-- SNIPERS ----------------------------------------------------------------------------------
	-- Mata-Pato: sniper leve verde de ferrolho, coronha inteiriça, luneta média.
	weapon_matapato = function(c, p)
		local green, black = c.body, c.dark
		B(p, 0.22, 0.34, 0.6, 0, 0.0, 0.9, green) -- coronha
		B(p, 0.223, 0.14, 0.3, 0, -0.03, 0.82, black) -- vão do polegar
		B(p, 0.24, 0.4, 0.06, 0, -0.01, 1.22, black)
		B(p, 0.2, 0.2, 1.6, 0, 0.08, -0.25, green) -- coronha comprida até a frente
		B(p, 0.205, 0.04, 1.4, 0, 0.17, -0.3, c.accent) -- faixa
		B(p, 0.18, 0.16, 0.7, 0, 0.24, 0.0, c.metal) -- ação
		C(p, 0.18, 0.05, 0.14, 0.26, 0.18, black, "X") -- alavanca do ferrolho
		C(p, 0.05, 0.09, 0.24, 0.24, 0.18, black, "Y")
		pistolGrip(p, c, 0.35, -0.13, green)
		straightMag(p, c, -0.05, -0.02, 0.18)
		scope(p, c, 0.0, 0.48, 0.75, 0.12, 0.32)
		C(p, 1.35, 0.09, 0, 0.2, -1.55, black)
		local muzzle = brake(p, c, -2.28, 0.2, 0.13, 0.18)
		return muzzle, Vector3.new(0, 0.0, -0.75), RIFLE_GRIP + Vector3.new(0, 0.08, 0.08)
	end,
	-- Gêmea: sniper branca de cano duplo sobreposto, luneta e coronha clara.
	weapon_gemea = function(c, p)
		local white, black = c.body, c.dark
		B(p, 0.24, 0.42, 0.07, 0, 0.02, 1.2, black)
		B(p, 0.22, 0.3, 0.55, 0, 0.06, 0.92, white)
		B(p, 0.223, 0.12, 0.25, 0, 0.0, 0.88, black)
		B(p, 0.24, 0.3, 0.95, 0, 0.12, 0.15, white) -- receptor
		B(p, 0.245, 0.06, 0.95, 0, 0.0, 0.15, black)
		B(p, 0.245, 0.07, 0.24, 0, 0.2, 0.25, c.metal)
		B(p, 0.25, 0.04, 0.95, 0, 0.27, 0.15, c.accent)
		pistolGrip(p, c, 0.32, -0.17)
		straightMag(p, c, -0.1, -0.03, 0.28)
		rail(p, 0.55, -0.3, 0.29, black)
		scope(p, c, 0.1, 0.52, 0.8, 0.13, 0.32)
		B(p, 0.22, 0.34, 0.5, 0, 0.18, -0.6, white) -- bloco dos canos
		for _, y in { 0.1, 0.27 } do
			C(p, 1.25, 0.1, 0, y, -1.45, black) -- cano duplo
			C(p, 0.12, 0.14, 0, y, -2.1, c.metal)
		end
		B(p, 0.06, 0.24, 0.06, 0, 0.185, -1.3, black) -- presilha dos canos
		return Vector3.new(0, 0.27, -2.17), Vector3.new(0, -0.02, -0.6), RIFLE_GRIP + Vector3.new(0, 0.04, 0.05)
	end,
	-- Luneta: sniper pesada dourada, luneta grande com para-sol, bipé e freio grande.
	weapon_luneta = function(c, p)
		local gold, black = c.body, c.dark
		B(p, 0.26, 0.46, 0.08, 0, 0.0, 1.3, black)
		B(p, 0.24, 0.16, 0.6, 0, 0.17, 1.0, gold)
		B(p, 0.24, 0.12, 0.6, 0, -0.15, 1.0, gold)
		B(p, 0.24, 0.4, 0.1, 0, 0.01, 0.74, gold)
		B(p, 0.2, 0.07, 0.34, 0, 0.29, 1.05, black) -- apoio do rosto
		B(p, 0.28, 0.32, 1.1, 0, 0.1, 0.18, gold) -- receptor
		B(p, 0.285, 0.07, 1.1, 0, -0.03, 0.18, black)
		B(p, 0.285, 0.08, 0.26, 0, 0.18, 0.3, c.metal)
		C(p, 0.2, 0.06, 0.16, 0.2, 0.36, black, "X")
		C(p, 0.06, 0.1, 0.27, 0.2, 0.36, black, "Y")
		pistolGrip(p, c, 0.38, -0.17)
		B(p, 0.2, 0.18, 0.28, 0, -0.12, -0.1, gold)
		straightMag(p, c, -0.1, -0.21, 0.28)
		rail(p, 0.7, -0.6, 0.29, black)
		scope(p, c, 0.05, 0.62, 1.1, 0.17, 0.32)
		C(p, 0.18, 0.36, 0, 0.62, -0.75, black) -- para-sol
		B(p, 0.27, 0.26, 0.6, 0, 0.12, -0.72, black) -- guarda-mão
		slots(p, { -0.55, -0.72, -0.89 }, 0.12, 0.27, 0.06, 0.1, c.metal)
		for _, x in { -0.12, 0.12 } do -- bipé
			B(p, 0.05, 0.52, 0.05, x, -0.18, -0.95, black, -10)
			B(p, 0.08, 0.04, 0.1, x, -0.44, -0.9, black)
		end
		C(p, 1.2, 0.12, 0, 0.17, -1.6, black)
		local muzzle = brake(p, c, -2.34, 0.17, 0.22, 0.3)
		return muzzle, Vector3.new(0, -0.02, -0.72), RIFLE_GRIP + Vector3.new(0, 0.04, 0.11)
	end,

	-- METRALHADORAS ----------------------------------------------------------------------------
	-- Martelo: metralhadora leve com caixa de munição, alça, capa de cano furada e bipé recolhido.
	weapon_martelo = function(c, p)
		local body, black = c.body, c.dark
		B(p, 0.26, 0.46, 0.08, 0, 0.02, 1.18, black)
		B(p, 0.24, 0.32, 0.5, 0, 0.1, 0.9, body)
		B(p, 0.243, 0.12, 0.3, 0, 0.06, 0.9, black)
		B(p, 0.36, 0.4, 1.15, 0, 0.16, 0.08, body) -- receptor
		B(p, 0.365, 0.06, 1.15, 0, 0.36, 0.08, black) -- tampa
		B(p, 0.365, 0.08, 0.3, 0, 0.2, 0.25, c.metal)
		rail(p, 0.5, -0.4, 0.39, black)
		B(p, 0.12, 0.14, 0.5, 0, 0.56, -0.2, black) -- alça
		B(p, 0.12, 0.14, 0.06, 0, 0.46, 0.02, black)
		B(p, 0.12, 0.14, 0.06, 0, 0.46, -0.42, black)
		pistolGrip(p, c, 0.4, -0.13)
		local mag = #p + 1
		B(p, 0.42, 0.42, 0.42, 0, -0.26, -0.2, black) -- caixa de munição
		B(p, 0.425, 0.06, 0.42, 0, -0.2, -0.2, c.accent)
		markMag(p, mag)
		B(p, 0.3, 0.12, 0.08, 0, -0.06, -0.03, c.metal) -- fita
		C(p, 0.85, 0.22, 0, 0.18, -0.95, black) -- capa do cano
		for _, z in { -0.7, -0.85, -1.0, -1.15 } do
			C(p, 0.07, 0.15, 0.09, 0.18, z, c.metal, "X") -- furos
		end
		for _, x in { -0.09, 0.09 } do
			B(p, 0.04, 0.04, 0.6, x, 0.02, -1.0, black) -- bipé recolhido
		end
		C(p, 0.4, 0.13, 0, 0.18, -1.55, black)
		local muzzle = brake(p, c, -1.84, 0.18, 0.18, 0.22)
		return muzzle, Vector3.new(0, 0.0, -0.9), RIFLE_GRIP + Vector3.new(0, 0.08, 0.13)
	end,
	-- Moedor: metralhadora giratória prateada com 6 canos, motor e caixa de munição.
	weapon_moedor = function(c, p)
		local silver, black = c.body, c.dark
		B(p, 0.42, 0.46, 0.7, 0, 0.12, 0.35, silver) -- carcaça de trás
		B(p, 0.425, 0.08, 0.7, 0, 0.36, 0.35, black)
		C(p, 0.3, 0.3, 0, 0.12, 0.78, black) -- motor
		C(p, 0.05, 0.32, 0, 0.12, 0.66, c.accent)
		B(p, 0.1, 0.1, 0.5, 0, 0.5, 0.35, black) -- alça de cima
		B(p, 0.1, 0.14, 0.06, 0, 0.42, 0.14, black)
		B(p, 0.1, 0.14, 0.06, 0, 0.42, 0.56, black)
		pistolGrip(p, c, 0.45, -0.17)
		local mag = #p + 1
		B(p, 0.38, 0.36, 0.4, 0.3, -0.12, 0.2, black) -- caixa de munição
		B(p, 0.385, 0.05, 0.4, 0.3, -0.04, 0.2, c.accent)
		markMag(p, mag)
		C(p, 0.35, 0.44, 0, 0.12, -0.15, silver) -- carcaça da frente
		for i = 0, 5 do -- 6 canos
			local a = i * math.pi / 3
			C(p, 1.25, 0.075, math.cos(a) * 0.12, 0.12 + math.sin(a) * 0.12, -0.92, black)
		end
		C(p, 0.07, 0.4, 0, 0.12, -0.75, c.metal) -- presilha do meio
		C(p, 0.08, 0.4, 0, 0.12, -1.5, c.metal) -- presilha da frente
		C(p, 0.04, 0.42, 0, 0.12, -1.53, c.accent)
		return Vector3.new(0, 0.12, -1.58), Vector3.new(0.0, 0.0, -0.3), RIFLE_GRIP + Vector3.new(0, 0.04, 0.18)
	end,

	-- CORPO A CORPO ----------------------------------------------------------------------------
	-- Bastão: taco de madeira com pomo, fita com relevo, corpo que engrossa e anel laranja.
	weapon_bastao = function(c, p)
		local wood = c.body
		local light = wood:Lerp(Color3.new(1, 1, 1), 0.2)
		C(p, 0.07, 0.22, 0, 0, 0.34, c.dark) -- pomo
		C(p, 0.6, 0.13, 0, 0, 0.0, c.dark) -- cabo
		for i = 0, 4 do
			C(p, 0.03, 0.145, 0, 0, 0.24 - i * 0.12, c.light) -- relevo da fita
		end
		C(p, 0.3, 0.15, 0, 0, -0.42, wood)
		C(p, 0.35, 0.18, 0, 0, -0.74, wood)
		C(p, 0.05, 0.195, 0, 0, -0.6, c.accent) -- anel
		C(p, 0.4, 0.22, 0, 0, -1.1, light)
		C(p, 0.3, 0.25, 0, 0, -1.45, light)
		C(p, 0.04, 0.26, 0, 0, -1.62, wood) -- ponta
		return Vector3.new(0, 0, -1.65), nil, Vector3.new(0, 0, 0.05)
	end,
}

-- Modelo detalhado da arma, ou nil se ela ainda não tem um.
function WeaponModels.build(id: string, look: Look): Built?
	local builder = MODELS[id]
	if builder == nil then
		return nil
	end
	local parts: Parts = {}
	local muzzle, leftHand, grip = builder(look, parts)
	return { parts = parts, muzzle = muzzle, leftHand = leftHand, grip = grip }
end

function WeaponModels.has(id: string): boolean
	return MODELS[id] ~= nil
end

return WeaponModels
