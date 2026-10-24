local I18n = require("src.i18n.I18n")

local tests = {}

function tests.catalogs_translate_menu_settings_and_formatted_strings()
    I18n.setLanguage("pt")
    assert(I18n.t("menu.settings") == "Configurações")
    I18n.setLanguage("en")
    assert(I18n.t("settings.music_volume") == "Music volume")
    assert(I18n.t("levels.page", 2, 3) == "A/D or ←/→  ·  Page 2/3")
    I18n.setLanguage("es")
    assert(I18n.t("pause.resume") == "Continuar")
	assert(I18n.t("tutorial.first_tutorial")
		== "Usa las teclas de dirección para empujar la caja hasta la placa de presión.")
    assert(I18n.t("credits.rogues_detail")
        == "Seth Boyles - términos de uso: assets/LICENSE.txt")
    I18n.setLanguage("en")
    assert(I18n.t("credits.fonts_detail")
        == "Soft Type Project - SIL OFL 1.1 - licenses in assets/fonts/")
    I18n.setLanguage("pt")
	assert(I18n.t("tutorial.first_tutorial")
		== "Use os direcionais para empurrar a caixa até a placa de pressão.")
	assert(I18n.t("tutorial.undo", "K")
		== "Pressione K ou o botão de desfazer para voltar no tempo.")
	assert(I18n.t("tutorial.change_player", "J", "J")
		== "Pressione J para alternar entre personagens ou segure J e use uma direção para escolher.")
end

return tests
