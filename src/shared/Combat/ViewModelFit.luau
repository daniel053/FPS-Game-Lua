--!strict
-- Enquadramento da arma em primeira pessoa (guia `docs/referencias/visuais/guia-arma-primeira-pessoa.png`,
-- regras de enquadramento). Funções puras: usadas pelo ViewModel (cliente) e pelos testes.
--
-- Com a arma na posição da categoria (`CombatConfig.ViewModel.Offsets`), confere numa tela de
-- referência (16:9, campo de visão da câmera) se:
--   * a ponta do cano fica fora do centro (à direita de `MuzzleMinX` e abaixo de `MuzzleMinY`);
--   * nenhuma peça (arma, mãos, braços) sai da ZONA DA ARMA (`ZoneMinX`, `ZoneMinY`);
--   * nenhuma peça entra no CENTRO LIVRE (círculo de raio `CenterRadius` da altura, em volta do centro).
-- Se não couber, a arma fica menor (o guia: "se precisar, a arma fica menor, não o HUD"), em passos,
-- até `MinScale`. A escala vale em volta da origem do modelo (a empunhadura), então o cano encolhe
-- na direção da mão.

local CharacterConfig = require(script.Parent.Parent.Config.CharacterConfig)
local CombatConfig = require(script.Parent.Parent.Config.CombatConfig)

local FRAME = CombatConfig.ViewModel.Frame

-- Peça do modelo (o WeaponShapes.PartSpec tem mais campos; só o tamanho e a posição importam aqui).
export type Spec = { size: Vector3, cframe: CFrame, [any]: any }

export type Report = {
	muzzle: Vector2, -- posição na tela (0 a 1, da esquerda e de cima)
	left: number, -- peça mais à esquerda (0 a 1)
	top: number, -- peça mais alta (0 a 1)
	center: boolean, -- alguma peça entra no centro livre
	fits: boolean,
}

local ViewModelFit = {}

-- Ponto em espaço de câmera → tela de referência (0 a 1). nil = atrás da câmera.
local function toScreen(p: Vector3, tanHalf: number, aspect: number): Vector2?
	if p.Z > -0.05 then
		return nil
	end
	local x = p.X / -p.Z / (tanHalf * aspect)
	local y = p.Y / -p.Z / tanHalf
	return Vector2.new((x + 1) / 2, (1 - y) / 2)
end

-- Como a arma aparece com `scale`, na posição `offset` em relação à câmera.
function ViewModelFit.measure(parts: { Spec }, muzzle: Vector3, offset: Vector3, scale: number, fov: number?): Report
	local tanHalf = math.tan(math.rad(fov or CharacterConfig.Camera.FieldOfView) / 2)
	local aspect = FRAME.RefAspect
	local pivot = CFrame.new(offset)
	local left, top, center = 1, 1, false
	for _, spec in parts do
		local cf = pivot * CFrame.new(spec.cframe.Position * scale) * spec.cframe.Rotation
		local h = spec.size * scale / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local s = toScreen(cf * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z), tanHalf, aspect)
					-- só o que fica dentro da tela conta (o resto do braço sai por baixo)
					if s and s.X >= 0 and s.X <= 1 and s.Y >= 0 and s.Y <= 1 then
						left = math.min(left, s.X)
						top = math.min(top, s.Y)
						local dx, dy = (s.X - 0.5) * aspect, s.Y - 0.5
						if math.sqrt(dx * dx + dy * dy) < FRAME.CenterRadius then
							center = true
						end
					end
				end
			end
		end
	end
	local m = toScreen(pivot * (muzzle * scale), tanHalf, aspect) or Vector2.new(1, 1)
	local fits = m.X >= FRAME.MuzzleMinX
		and m.Y >= FRAME.MuzzleMinY
		and left >= FRAME.ZoneMinX
		and top >= FRAME.ZoneMinY
		and not center
	return { muzzle = m, left = left, top = top, center = center, fits = fits }
end

-- Maior escala (de 1 para baixo, em passos de `ScaleStep`) em que a arma cabe no quadro, por cima da
-- escala `base` (celular: 0,9). Se nem a `MinScale` couber, devolve a `MinScale` (o teste acusa).
function ViewModelFit.scale(parts: { Spec }, muzzle: Vector3, offset: Vector3, base: number?, fov: number?): number
	local scale = 1
	while scale > FRAME.MinScale + 1e-6 do
		if ViewModelFit.measure(parts, muzzle, offset, scale * (base or 1), fov).fits then
			return scale
		end
		scale -= FRAME.ScaleStep
	end
	return FRAME.MinScale
end

return ViewModelFit
