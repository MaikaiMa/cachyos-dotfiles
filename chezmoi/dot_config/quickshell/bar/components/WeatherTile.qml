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
        const day = Qt.locale("nl_NL").dayName(date.getDay(), Locale.ShortFormat).replace(/\.$/, "");
        return day.charAt(0).toUpperCase() + day.slice(1);
    }

    Row {
        id: now

        x: Theme.homeTilePadding
        y: Theme.homeTilePadding
        width: parent.width - 2 * Theme.homeTilePadding
        height: Theme.weatherNowHeight
        spacing: Theme.homeSectionGap

        WeatherIcon {
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.weatherNowIconSize
            condition: Weather.ready ? Weather.iconName : ""
        }

        Text {
            objectName: "weatherTemperature"
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.ready ? tile.degrees(Weather.temperature) : "–"
            color: Colors.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.homeLargeFontSize
            font.weight: Font.DemiBold
            font.features: ({
                    tnum: 1
                })
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            Text {
                objectName: "weatherCondition"
                text: Weather.ready ? Weather.conditionText : ""
                color: Colors.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
            }

            Text {
                objectName: "weatherFeelsLike"
                text: Weather.ready ? "Voelt als " + tile.degrees(Weather.apparent) + (Weather.place !== "" ? " · " + Weather.place : "") : ""
                color: Colors.foregroundVariant
                font.family: Theme.fontFamily
                font.pixelSize: Theme.secondaryFontSize
                font.weight: Theme.fontWeight
                font.features: ({
                        tnum: 1
                    })
            }
        }
    }

    SegmentedControl {
        objectName: "weatherTabs"
        x: Theme.homeTilePadding
        y: now.y + now.height + Theme.homeSectionGap
        width: Theme.weatherTabsWidth
        label: "Forecast"
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

        CardRow {
            objectName: "hourlyCards"
            width: cards.width
            shown: tile.tab === "hourly"

            Repeater {
                model: Theme.weatherCardCount

                WeatherCard {
                    required property int index

                    readonly property var hour: Weather.hourly[index] ?? null

                    label: hour ? hour.time : "–"
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

                    label: day ? tile.weekday(day.date) : "–"
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
        // Five fixed cards spread over the row.
        spacing: (width - Theme.weatherCardCount * Theme.weatherCardWidth) / (Theme.weatherCardCount - 1)
        opacity: shown ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.crossfadeDuration
                easing.type: Motion.crossfadeEasing
            }
        }
    }

    component WeatherCard: Rectangle {
        id: card

        property string label: ""
        property string condition: ""
        property string high: ""
        property string low: ""

        width: Theme.weatherCardWidth
        height: Theme.weatherCardHeight
        radius: Theme.weatherCardRadius
        color: Colors.surfaceContainer

        Accessible.role: Accessible.StaticText
        Accessible.name: label + " " + high + (low !== "" ? " " + low : "")

        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                objectName: "cardLabel"
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.label
                color: Colors.foregroundVariant
                font.family: Theme.fontFamily
                font.pixelSize: Theme.secondaryFontSize
                font.weight: Theme.fontWeight
                font.features: ({
                        tnum: 1
                    })
            }

            WeatherIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                size: Theme.toggleIconSize
                condition: card.condition
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 3

                Text {
                    objectName: "cardHigh"
                    text: card.high
                    color: Colors.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.homeDetailFontSize
                    font.weight: Font.DemiBold
                    font.features: ({
                            tnum: 1
                        })
                }

                Text {
                    objectName: "cardLow"
                    visible: card.low !== ""
                    text: card.low
                    color: Colors.foregroundVariant
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.homeDetailFontSize
                    font.weight: Font.DemiBold
                    font.features: ({
                            tnum: 1
                        })
                }
            }
        }
    }
}
