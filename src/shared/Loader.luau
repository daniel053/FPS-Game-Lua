--!strict
-- Carrega os módulos de uma ou mais pastas e chama Init() em todos, depois Start() em todos.
-- Usado pelos scripts Boot do servidor e do cliente.
--   Init(): preparar (criar remotes, ler config). Não deve esperar (yield).
--   Start(): ligar conexões e loops. Cada Start roda separado; um erro não derruba os outros.

type Module = {
	Init: (() -> ())?,
	Start: (() -> ())?,
}

local Loader = {}

function Loader.run(folders: { Instance? })
	local loaded: { { name: string, module: Module } } = {}

	for _, folder in folders do
		if folder == nil then
			continue
		end
		for _, child in folder:GetChildren() do
			if child:IsA("ModuleScript") then
				local module = (require(child) :: any) :: Module
				table.insert(loaded, { name = child:GetFullName(), module = module })
			end
		end
	end

	for _, entry in loaded do
		local init = entry.module.Init
		if init then
			init()
		end
	end

	for _, entry in loaded do
		local start = entry.module.Start
		if start then
			-- Cada Start roda na sua própria thread: um erro aparece no Output com o
			-- nome do módulo e a pilha, sem impedir os outros de iniciar.
			task.spawn(start)
		end
	end
end

return Loader
