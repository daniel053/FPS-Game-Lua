--!strict
-- Iluminação por mapa (LightingConfig, Theme.MapGrade): todo mapa tem ajuste e todo ajuste é sutil.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LightingConfig = require(ReplicatedStorage.Shared.Config.LightingConfig)
local MapConfig = require(ReplicatedStorage.Shared.Config.MapConfig)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

return function(t: any)
	t.test("cada mapa da partida tem ajuste de luz e tinta", function()
		for _, map in MapConfig.Maps do
			t.ok(LightingConfig.Maps[map.id] ~= nil, `{map.id} sem ajuste em LightingConfig`)
			local tint: Color3? = Theme.MapGrade[map.id]
			t.ok(tint ~= nil, `{map.id} sem tinta em Theme.MapGrade`)
		end
	end)

	t.test("ajustes de luz dentro dos limites (sutis)", function()
		local limits = LightingConfig.Limits
		for id, preset in LightingConfig.Maps do
			t.ok(math.abs(preset.Saturation) <= limits.Saturation, `{id}: saturação forte demais`)
			t.ok(math.abs(preset.Contrast) <= limits.Contrast, `{id}: contraste forte demais`)
			t.ok(math.abs(preset.Brightness) <= limits.Brightness, `{id}: brilho forte demais`)
			t.ok(math.abs(preset.Exposure) <= limits.Exposure, `{id}: exposição forte demais`)
		end
		for id, tint in Theme.MapGrade do
			local lowest = math.min(tint.R, tint.G, tint.B)
			t.ok(lowest >= limits.TintMinChannel, `{id}: tinta escura ou colorida demais`)
		end
	end)
end
