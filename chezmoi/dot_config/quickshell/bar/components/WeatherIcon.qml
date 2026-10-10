import QtQuick

// A Weather service icon name ("partly-cloudy-day") as its Material Symbols glyph.
Icon {
    property string condition: ""

    readonly property var symbols: ({
            "clear-day": "clear_day",
            "clear-night": "clear_night",
            "partly-cloudy-day": "partly_cloudy_day",
            "partly-cloudy-night": "partly_cloudy_night",
            "cloudy": "cloud",
            "fog": "foggy",
            "drizzle": "rainy",
            "rain": "rainy",
            "snow": "weather_snowy",
            "thunderstorm": "thunderstorm"
        })

    name: symbols[condition] ?? ""
}
