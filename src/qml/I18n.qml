pragma Singleton
import QtQuick
import "translations.js" as Translations

QtObject {
    id: root

    property string language: "zh_CN"

    readonly property var languages: [
        { code: "zh_CN", name: "简体中文" },
        { code: "zh_TW", name: "繁體中文" },
        { code: "en_US", name: "English" },
        { code: "ja_JP", name: "日本語" },
        { code: "de_DE", name: "Deutsch" },
        { code: "ru_RU", name: "Русский" },
        { code: "ko_KR", name: "한국어" }
    ]

    function t(text) {
        var table = Translations.translations[root.language]
        if (table && table[text] !== undefined) {
            return table[text]
        }
        return text
    }

    function f(text, args) {
        var result = t(text)
        if (!args) {
            return result
        }
        for (var i = 0; i < args.length; ++i) {
            result = result.replace("{" + i + "}", String(args[i]))
        }
        return result
    }

    function languageName(code) {
        for (var i = 0; i < languages.length; ++i) {
            if (languages[i].code === code) {
                return languages[i].name
            }
        }
        return code
    }
}
