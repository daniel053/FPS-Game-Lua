--!strict
-- Marcação de aliado e inimigo (GDD 7.6) [DECIDIDO], como regra pura (testável sem cliente).
--
--   | Situação                          | Contorno                   | Barra sobre a cabeça | Nome            |
--   | inimigo à vista                   | vermelho pulsando          | vermelha             | —               |
--   | inimigo atrás de parede ou Nuvem  | —                          | —                    | —               |
--   | aliado à vista (qualquer parte)   | —                          | verde                | branco          |
--   | aliado com o corpo todo escondido | silhueta verde (atravessa) | —                    | —               |
--   | quem assiste do mirante           | —                          | —                    | cor da equipe   |
--
-- Só entre jogadores da mesma ilha. Quem foi derrubado e assiste ao parceiro não vê nada.

export type Outline = "None" | "Enemy" | "AllySilhouette"
export type Bar = "None" | "Enemy" | "Ally"
export type Name = "None" | "Ally" | "Team"

export type Input = {
	isSelf: boolean,
	alive: boolean,
	isPartner: boolean,
	sameIsland: boolean,
	anyPartVisible: boolean, -- algum dos pontos do corpo à vista (raios da câmera)
	behindSmoke: boolean, -- a linha até ele passa por uma Nuvem (F4)
	viewerOnMirante: boolean, -- quem olha está no mirante
	targetOnIsland: boolean, -- o alvo está jogando numa ilha
}

export type State = { outline: Outline, bar: Bar, name: Name }

local MarkerRules = {}

local NONE: State = table.freeze({ outline = "None", bar = "None", name = "None" }) :: any

function MarkerRules.decide(input: Input): State
	if input.isSelf or not input.alive then
		return NONE
	end
	if input.viewerOnMirante then
		-- Do mirante, só o nome na cor da equipe de quem está duelando (sem contorno, sem barra)
		if input.targetOnIsland then
			return { outline = "None", bar = "None", name = "Team" }
		end
		return NONE
	end
	if not input.sameIsland then
		return NONE
	end
	if input.isPartner then
		if input.anyPartVisible then
			return { outline = "None", bar = "Ally", name = "Ally" }
		end
		return { outline = "AllySilhouette", bar = "None", name = "None" }
	end
	if input.anyPartVisible and not input.behindSmoke then
		return { outline = "Enemy", bar = "Enemy", name = "None" }
	end
	return NONE
end

-- Transparência do contorno do inimigo no instante `t` (pulso suave, em seno). Sem pulso quando
-- o jogador pede para reduzir efeitos (ESTILO 5).
function MarkerRules.pulse(
	t: number,
	period: number,
	minValue: number,
	maxValue: number,
	reduceEffects: boolean
): number
	if reduceEffects or period <= 0 then
		return minValue
	end
	local wave = (math.sin(t / period * 2 * math.pi) + 1) / 2 -- 0..1
	return minValue + (maxValue - minValue) * wave
end

-- Frações da barra: vida (0..1) e escudo (0..1).
function MarkerRules.barFractions(hp: number, shield: number, maxHp: number, maxShield: number): (number, number)
	local hpFraction = if maxHp > 0 then math.clamp(hp / maxHp, 0, 1) else 0
	local shieldFraction = if maxShield > 0 then math.clamp(shield / maxShield, 0, 1) else 0
	return hpFraction, shieldFraction
end

return MarkerRules
