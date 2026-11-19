--!strict
-- Versão leve dos mapas (GDD 13.2, F10): qual peça pode sumir na tela de quem precisa de desempenho.
-- Regra pura (usada pelo cliente, MapDetailLevel, e pelos testes):
--   * só peças de ACABAMENTO (atributo MapDetail: não colidem nem bloqueiam tiro);
--   * nunca um SINAL (atributo MapSignal: setas da esteira, faixas de aviso, vagas);
--   * só as pequenas (maior face menor que MapConfig.Performance.DetailMinFace studs²): juntas,
--     ondulação, frisos, tábuas. As grandes (telhados de cenário, janelas, ferrugem) ficam.

local Build = require(script.Parent.Build)
local MapConfig = require(script.Parent.Parent.Config.MapConfig)

local MapDetail = {}

-- Maior face da peça (studs²).
function MapDetail.largestFace(size: Vector3): number
	return math.max(size.X * size.Y, size.Y * size.Z, size.X * size.Z)
end

function MapDetail.isOptional(part: BasePart): boolean
	if part:GetAttribute(Build.DetailAttribute) ~= true or part:GetAttribute(Build.SignalAttribute) == true then
		return false
	end
	return MapDetail.largestFace(part.Size) < MapConfig.Performance.DetailMinFace
end

return MapDetail
