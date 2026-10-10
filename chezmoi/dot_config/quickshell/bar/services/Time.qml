pragma Singleton

import QtQuick
import Quickshell

// The bar's one minute clock and the Dutch short names its dates use.
Singleton {
    id: root

    readonly property date date: clock.date

    // "zo", or "Zo" capitalised; Qt's Dutch short names may end in a full
    // stop ("okt."), the design has none.
    function shortDay(date: date, capitalised: bool): string {
        const day = Qt.locale("nl_NL").dayName(date.getDay(), Locale.ShortFormat).replace(/\.$/, "");
        return capitalised ? day.charAt(0).toUpperCase() + day.slice(1) : day;
    }

    function shortMonth(date: date): string {
        return Qt.locale("nl_NL").monthName(date.getMonth(), Locale.ShortFormat).replace(/\.$/, "");
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }
}
