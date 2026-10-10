pragma ComponentBehavior: Bound

import QtQuick
import "../panels"

// The eleven centre panels, each at its own settled size and centred on the
// island, which clips them while it grows. The panel whose name is the
// island's state shows; current is that panel, or null, and carries the size
// the island grows to.
Item {
    id: host

    property string centreState: ""

    readonly property list<Panel> panels: [homePanel, settingsPanel, updatesPanel, playerPanel, powerPanel, themePanel, wallpaperPanel, wifiPanel, bluetoothPanel, soundPanel, displayPanel]
    readonly property Panel current: panels.find(panel => panel.name === centreState) ?? null

    HomePanel {
        id: homePanel

        shown: host.current === homePanel
    }

    SettingsPanel {
        id: settingsPanel

        shown: host.current === settingsPanel
    }

    UpdatesPanel {
        id: updatesPanel

        shown: host.current === updatesPanel
    }

    PlayerPanel {
        id: playerPanel

        shown: host.current === playerPanel
    }

    PowerPanel {
        id: powerPanel

        shown: host.current === powerPanel
    }

    ThemePanel {
        id: themePanel

        shown: host.current === themePanel
    }

    WallpaperPanel {
        id: wallpaperPanel

        shown: host.current === wallpaperPanel
    }

    WifiPanel {
        id: wifiPanel

        shown: host.current === wifiPanel
    }

    BluetoothPanel {
        id: bluetoothPanel

        shown: host.current === bluetoothPanel
    }

    SoundPanel {
        id: soundPanel

        shown: host.current === soundPanel
    }

    DisplayPanel {
        id: displayPanel

        shown: host.current === displayPanel
    }
}
