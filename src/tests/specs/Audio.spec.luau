--!strict
-- Sons (GDD 7.7, F10): todo som tem o seu arquivo gerado (`assets/sons`, `AudioAssets`) e, enquanto o
-- arquivo não foi enviado ao Roblox, toca o provisório.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local AudioAssets = require(Shared.Config.AudioAssets)
local AudioConfig = require(Shared.Config.AudioConfig)
local WeaponConfig = require(Shared.Config.WeaponConfig)

local function allDefs(): { [string]: AudioConfig.SoundDef }
	local defs: { [string]: AudioConfig.SoundDef } = {}
	for key, value in AudioConfig :: any do
		if typeof(value) == "table" and value.volume then
			defs[key] = value
		elseif typeof(value) == "table" then
			for sub, def in value do
				if typeof(def) == "table" and def.volume then
					defs[`{key}.{sub}`] = def
				end
			end
		end
	end
	return defs
end

return function(t: any)
	t.test("todo som tem arquivo gerado e um lugar para o número do asset", function()
		local used: { [string]: boolean } = {}
		for name, def in allDefs() do
			t.ok(def.file ~= nil, `{name}: tem arquivo`)
			if def.file then
				t.ok(AudioAssets[def.file] ~= nil, `{name}: "{def.file}" está em AudioAssets`)
				used[def.file] = true
			end
		end
		for file in AudioAssets do
			t.ok(used[file], `AudioAssets.{file} é usado por algum som`)
		end
	end)

	t.test("cada arma de fogo tem um som de tiro próprio", function()
		local files: { [string]: string } = {}
		for _, round in { 1, 3, 4 } do
			for _, list in { WeaponConfig.getPrimariesForRound(round), WeaponConfig.getSecondariesForRound(round) } do
				for _, id in list do
					local def = AudioConfig.WeaponFire[id]
					t.ok(def ~= nil, `{id}: tem som`)
					if def and def.file then
						t.ok(files[def.file] == nil or files[def.file] == id, `{id}: som repetido`)
						files[def.file] = id
					end
				end
			end
		end
	end)

	t.test("sem número do asset toca o provisório; com número, o final no tom 1", function()
		local def: AudioConfig.SoundDef = { id = "rbxasset://x", file = "crack_abate", volume = 1, pitch = 0.8 }
		local saved = AudioAssets.crack_abate
		AudioAssets.crack_abate = 0
		local id, pitch = AudioConfig.resolve(def)
		t.eq(id, "rbxasset://x")
		t.eq(pitch, 0.8)
		AudioAssets.crack_abate = 123
		id, pitch = AudioConfig.resolve(def)
		t.eq(id, "rbxassetid://123")
		t.eq(pitch, 1)
		AudioAssets.crack_abate = saved
	end)
end
