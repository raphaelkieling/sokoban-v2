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
    assert(I18n.t("credits.rogues_detail")
        == "Seth Boyles - términos de uso: assets/LICENSE.txt")
    I18n.setLanguage("en")
    assert(I18n.t("credits.fonts_detail")
        == "Soft Type Project - SIL OFL 1.1 - licenses in assets/fonts/")
    I18n.setLanguage("pt")
end

return tests
