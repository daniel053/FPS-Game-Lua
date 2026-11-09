--!strict
-- Todos os textos visíveis ao jogador, em português do Brasil (ESTILO-E-TELAS seção 0).
-- Nenhum texto visível é escrito direto no código. Facilita tradução futura.
-- Nomes próprios do jogo; nunca usar nomes de outros jogos.

local Strings = {
	GameName = "[NOME DO JOGO]", -- [ABERTO] (GDD 18, item 1)

	Places = {
		Lobby = "Lobby",
		Tutorial = "Tutorial",
		Match = "Partida",
	},

	WeaponCategories = {
		Pistol = "Pistolas",
		SMG = "Submetralhadoras",
		Shotgun = "Escopetas",
		LightRifle = "Fuzis leves",
		Rifle = "Fuzis",
		Sniper = "Snipers",
		MachineGun = "Metralhadoras",
	},

	WeaponPhases = {
		pistolas = "Pistolas",
		medias = "Armas médias",
		pesadas = "Armas pesadas",
	},

	-- Nomes das armas, por ID (GDD 7.2.3)
	Weapons = {
		weapon_bolinha = "Bolinha",
		weapon_chumbinho = "Chumbinho",
		weapon_zumbido = "Zumbido",
		weapon_precisa = "Precisa",
		weapon_tambor = "Tambor",
		weapon_ferrao = "Ferrão",
		weapon_vespa = "Vespa",
		weapon_balde = "Balde",
		weapon_varredor = "Varredor",
		weapon_tatico = "Tático",
		weapon_atirador = "Atirador",
		weapon_martelo = "Martelo",
		weapon_moedor = "Moedor",
		weapon_rajada = "Rajada",
		weapon_trovao = "Trovão",
		weapon_matapato = "Mata-Pato",
		weapon_gemea = "Gêmea",
		weapon_luneta = "Luneta",
		weapon_bastao = "Bastão",
	} :: { [string]: string },

	-- Cartas, por ID (GDD 8.4)
	Cards = {
		card_nuvem = { name = "Nuvem", description = "Arremessa uma nuvem que bloqueia a visão." },
		card_impulso = { name = "Impulso", description = "Lança você bem alto para cima." },
		card_tremor = {
			name = "Tremor",
			description = "Onda no chão que deixa os inimigos lentos e com a mira tremida.",
		},
		card_renascer = {
			name = "Renascer",
			description = "Deixa uma marca: se cair em 8 s, volta a ela com vida cheia.",
		},
	} :: { [string]: { name: string, description: string } },

	Rarities = {
		Comum = "Comum",
		Epica = "Épica",
		Lendaria = "Lendária",
		Celestial = "Celestial",
	},

	Ranks = {
		Bronze = "Bronze",
		Prata = "Prata",
		Ouro = "Ouro",
		Platina = "Platina",
		Mestre = "Mestre",
		Deus = "Deus",
		Adm = "ADM",
	},

	Maps = {
		map_praca = "Praça",
		map_fabrica = "Fábrica",
		map_porto = "Porto",
		map_torre = "Torre",
		mirante = "Mirante",
	},

	Teams = {
		Azul = "Azul",
		Laranja = "Laranja",
		Verde = "Verde",
		Roxo = "Roxo",
		Amarelo = "Amarelo",
		Branco = "Branco",
		Rosa = "Rosa",
		Ciano = "Ciano",
	},

	-- Painel de teste (só aparece no ambiente DEV_)
	Dev = {
		ToggleButton = "TESTE",
		PanelTitle = "TELEPORTE DE TESTE",
		CurrentPlace = "Você está em: %s",
		UnknownPlace = "place não configurado",
		GoTo = "IR PARA %s",
		Close = "FECHAR",
		GamepadHint = "↑",
		Results = {
			Sent = "Teleportando…",
			NotDev = "Teleporte de teste desligado neste ambiente.",
			Studio = "Teleporte não funciona dentro do Studio. Teste no jogo publicado.",
			NotConfigured = "Esse place ainda não tem ID em PlaceConfig.",
			SamePlace = "Você já está nesse place.",
			Cooldown = "Espere alguns segundos e tente de novo.",
			Invalid = "Pedido inválido.",
			Failed = "O teleporte falhou. Tente de novo.",
		} :: { [string]: string },
	},
}

return Strings
