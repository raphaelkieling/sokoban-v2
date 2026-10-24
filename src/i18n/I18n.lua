local catalogs = {
    pt = require("src.i18n.locales.pt"),
    en = require("src.i18n.locales.en"),
    es = require("src.i18n.locales.es"),
}

local I18n = {language = "pt"}

function I18n.setLanguage(language)
    if catalogs[language] then I18n.language = language end
end

function I18n.getLanguage()
    return I18n.language
end

local function lookup(catalog, key)
    local value = catalog
    for part in key:gmatch("[^%.]+") do
        value = type(value) == "table" and value[part] or nil
        if value == nil then return nil end
    end
    return value
end

function I18n.t(key, ...)
    local value = lookup(catalogs[I18n.language], key)
        or lookup(catalogs.en, key)
        or key
    if select("#", ...) > 0 then return string.format(value, ...) end
    return value
end

return I18n
