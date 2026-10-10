pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Home: the current weather, an Hourly / Daily switch and five forecast cards.
Rectangle {
    id: tile

    // hourly or daily; Hourly each time the bar starts.
    property string tab: "hourly"

    radius: Theme.tileRadius
    color: Colors.surfaceContainerHigh

    function degrees(value: real): string {
        return Math.round(value) + "°";
    }

    // "Ma" from "2026-10-05": the local weekday, not the UTC one.
    function weekday(isoDate: string): string {
        const parts = isoDate.split("-").map(Number);
        const date = new Date(parts[0], parts[1] - 1, parts[2]);
        return Time.shortDay(date, true);
    }

    Row {
        id: now

        x: Theme.homeTilePadding
        y: Theme.homeTilePadding
        width: parent.width - 2 * Theme.homeTilePadding
        height: Theme.weatherNowHeight
        spacing: Theme.homeSectionGap
        // An old reading stays readable, dimmed.
        opacity: Weather.stale ? Theme.busyOpacity : 1

        WeatherIcon {
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.weatherNowIconSize
            condition: Weather.ready ? Weather.iconName : ""
        }

        Label {
            objectName: "weatherTemperature"
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.ready ? tile.degrees(Weather.temperature) : "–"
            strong: true
            numeric: true
            font.pixelSize: Theme.homeLargeFontSize
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            Label {
                objectName: "weatherCondition"
                text: Weather.ready ? Weather.conditionText : ""
                strong: true
            }

            Label {
                objectName: "weatherFeelsLike"
                text: Weather.ready ? "Feels like " + tile.degrees(Weather.apparent) : ""
                secondary: true
                numeric: true
            }
        }
    }

    SegmentedControl {
        objectName: "weatherTabs"
        x: Theme.homeTilePadding
        y: now.y + now.height + Theme.homeSectionGap
        width: Theme.weatherTabsWidth
        accessibleName: "Forecast"
        model: ["Hourly", "Daily"]
        currentIndex: tile.tab === "daily" ? 1 : 0
        onSelected: index => tile.tab = index === 1 ? "daily" : "hourly"
    }

    // Both rows are always there and cross-fade; five cards each, "–" until data arrives.
    Item {
        id: cards

        x: Theme.homeTilePadding
        y: now.y + now.height + 2 * Theme.homeSectionGap + Theme.segmentedHeight
        width: parent.width - 2 * Theme.homeTilePadding
        height: Theme.weatherCardHeight
        opacity: Weather.stale ? Theme.busyOpacity : 1

        CardRow {
            objectName: "hourlyCards"
            width: cards.width
            shown: tile.tab === "hourly"

            Repeater {
                model: Theme.weatherCardCount

                WeatherCard {
                    required property int index

                    readonly property var hour: Weather.hourly[index] ?? null

                    text: hour ? hour.time : "–"
                    condition: hour ? hour.iconName : ""
                    high: hour ? tile.degrees(hour.temperature) : "–"
                }
            }
        }

        CardRow {
            objectName: "dailyCards"
            width: cards.width
            shown: tile.tab === "daily"

            Repeater {
                model: Theme.weatherCardCount

                WeatherCard {
                    required property int index

                    readonly property var day: Weather.daily[index] ?? null

                    text: day ? tile.weekday(day.date) : "–"
                    condition: day ? day.iconName : ""
                    high: day ? tile.degrees(day.max) : "–"
                    low: day ? tile.degrees(day.min) : ""
                }
            }
        }
    }

    component CardRow: Row {
        property bool shown: false

        height: Theme.weatherCardHeight
        spacing: (width - Theme.weatherCardCount * Theme.weatherCardWidth) / (Theme.weatherCardCount - 1)
        opacity: shown ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            Crossfade {}
        }
    }

    component WeatherCard: Rectangle {
        id: card

        property string text: ""
        property string condition: ""
        property string high: ""
        property string low: ""

        width: Theme.weatherCardWidth
        height: Theme.weatherCardHeight
        radius: Theme.weatherCardRadius
        color: Colors.surfaceContainer

        Accessible.role: Accessible.StaticText
        Accessible.name: text + " " + high + (low !== "" ? " " + low : "")

        Column {
            anchors.centerIn: parent
            spacing: Theme.weatherCardGap

            Label {
                objectName: "cardLabel"
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.text
                secondary: true
                numeric: true
            }

            WeatherIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                size: Theme.toggleIconSize
                condition: card.condition
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.weatherTemperatureGap

                Label {
                    objectName: "cardHigh"
                    text: card.high
                    strong: true
                    numeric: true
                    font.pixelSize: Theme.homeDetailFontSize
                }

                Label {
                    objectName: "cardLow"
                    visible: card.low !== ""
                    text: card.low
                    color: Colors.foregroundVariant
                    strong: true
                    numeric: true
                    font.pixelSize: Theme.homeDetailFontSize
                }
            }
        }
    }
}
