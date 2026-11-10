--!strict
-- Tamanho do texto da interface ajustável (ESTILO 5): 100%, 115% ou 130% (settings.uiScale).
-- Toda ScreenGui criada por Ui.screen é acompanhada: cada texto guarda o tamanho "base" que o código
-- definiu e mostra base × escala. Quando o código muda o TextSize, o valor novo vira a base.
-- Só o cliente usa (o SettingsController chama setScale ao carregar e a cada mudança do perfil).

type TextObject = TextLabel | TextButton | TextBox

local TextScale = {}

local scale = 1
local base: { [TextObject]: number } = setmetatable({} :: any, { __mode = "k" })
local shown: { [TextObject]: number } = setmetatable({} :: any, { __mode = "k" })

local function apply(obj: TextObject)
	local size = base[obj]
	if size == nil then
		return
	end
	local scaled = math.floor(size * scale + 0.5)
	shown[obj] = scaled
	local target: any = obj
	target.TextSize = scaled
end

local function watch(instance: Instance)
	if not (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")) then
		return
	end
	local obj = instance :: TextObject
	if base[obj] then
		return
	end
	base[obj] = obj.TextSize
	obj:GetPropertyChangedSignal("TextSize"):Connect(function()
		-- Mudança feita por apply (os sinais podem chegar depois): ignora
		if obj.TextSize == shown[obj] then
			return
		end
		base[obj] = obj.TextSize
		apply(obj)
	end)
	apply(obj)
end

function TextScale.get(): number
	return scale
end

function TextScale.setScale(value: number)
	if value == scale or value <= 0 then
		return
	end
	scale = value
	for obj in base do
		apply(obj)
	end
end

-- Acompanha todos os textos de uma tela (atuais e futuros).
function TextScale.track(gui: Instance)
	for _, d in gui:GetDescendants() do
		watch(d)
	end
	gui.DescendantAdded:Connect(watch)
end

return TextScale
