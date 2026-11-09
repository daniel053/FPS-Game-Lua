--!strict
-- Qual controle o jogador está usando agora: toque, teclado e mouse, ou controle.
-- Muda na hora quando o jogador troca (ex.: tablet com teclado). Usado para mostrar botões de toque
-- só no celular e dicas de tecla só no PC (ESTILO 3).

local UserInputService = game:GetService("UserInputService")

export type Device = "Touch" | "KeyboardMouse" | "Gamepad"

type Callback = (Device) -> ()

local InputDevice = {}

local callbacks: { Callback } = {}

local function fromInputType(inputType: Enum.UserInputType): Device?
	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	elseif inputType.Name:find("Gamepad") then
		return "Gamepad"
	elseif
		inputType == Enum.UserInputType.Keyboard
		or inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.MouseButton2
		or inputType == Enum.UserInputType.MouseMovement
		or inputType == Enum.UserInputType.MouseWheel
	then
		return "KeyboardMouse"
	end
	return nil
end

local function initialDevice(): Device
	local fromLast = fromInputType(UserInputService:GetLastInputType())
	if fromLast then
		return fromLast :: Device
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	end
	if UserInputService.GamepadEnabled and not UserInputService.MouseEnabled then
		return "Gamepad"
	end
	return "KeyboardMouse"
end

local current: Device = initialDevice()

function InputDevice.get(): Device
	return current
end

-- callback(device) a cada troca. Devolve uma função para desligar.
function InputDevice.onChanged(callback: Callback): () -> ()
	table.insert(callbacks, callback)
	return function()
		local index = table.find(callbacks, callback)
		if index then
			table.remove(callbacks, index)
		end
	end
end

function InputDevice.Start()
	UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
		local device = fromInputType(inputType)
		if device == nil or device == current then
			return
		end
		current = device :: Device
		for _, callback in callbacks do
			task.spawn(callback, device :: Device)
		end
	end)
end

return InputDevice
