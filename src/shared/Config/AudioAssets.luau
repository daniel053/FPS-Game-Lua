--!strict
-- Números dos sons finais no Roblox (F10). Cada arquivo de `assets/sons/` (gerado por
-- `scripts/sons/gerar.js`) é enviado ao Roblox pelo dono do projeto (Studio: Gerenciador de Assets ›
-- Importar em massa). O número do asset de cada um entra aqui; 0 = ainda não enviado (toca o
-- provisório do AudioConfig). README: "Sons".

local AudioAssets: { [string]: number } = {
	acerto = 0,
	carta_impulso = 0,
	carta_nuvem_arremesso = 0,
	carta_nuvem_puf = 0,
	carta_renascer_marca = 0,
	carta_renascer_volta = 0,
	carta_tremor = 0,
	crack_abate = 0,
	derrubado = 0,
	escudo_quebrado = 0,
	escudo_recarga = 0,
	frase = 0,
	golpe_forte = 0,
	golpe_leve = 0,
	ping = 0,
	recarga = 0,
	sacar = 0,
	sem_municao = 0,
	tiro_atirador = 0,
	tiro_balde = 0,
	tiro_bolinha = 0,
	tiro_chumbinho = 0,
	tiro_ferrao = 0,
	tiro_gemea = 0,
	tiro_luneta = 0,
	tiro_martelo = 0,
	tiro_matapato = 0,
	tiro_moedor = 0,
	tiro_precisa = 0,
	tiro_rajada = 0,
	tiro_tambor = 0,
	tiro_tatico = 0,
	tiro_trovao = 0,
	tiro_varredor = 0,
	tiro_vespa = 0,
	tiro_zumbido = 0,
}

return AudioAssets
