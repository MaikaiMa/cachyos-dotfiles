pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Current weather and a short forecast from Open-Meteo, every 15 minutes.
// Location: geoclue's where-am-i demo; else the last fix cached in
// $XDG_STATE_HOME/dotfiles-bar/weather-location.json; else Nijmegen.
Singleton {
    id: root

    readonly property string whereAmI: "/usr/lib/geoclue-2.0/demos/where-am-i"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/dotfiles-bar"
    readonly property real defaultLatitude: 51.84
    readonly property real defaultLongitude: 5.86

    property real latitude: NaN
    property real longitude: NaN

    property bool ready: false
    // The last fetch failed; the previous reading, if any, stays.
    property bool failed: false
    property date updated
    // The reading is more than staleAfter old, after a night offline for instance.
    readonly property real staleAfter: 60 * 60 * 1000
    readonly property bool stale: ready && internal.now - updated.getTime() > staleAfter
    property real temperature: 0
    property real apparent: 0
    property int code: -1
    property bool isDay: true
    readonly property string conditionText: describe(code)
    readonly property string iconName: iconFor(code, isDay)
    // Next 5 hours: {time ("15:00"), temperature, iconName}.
    property var hourly: []
    // Next 5 days after today: {date ("2026-10-05"), max, min, iconName}.
    property var daily: []

    readonly property int fetchInterval: 15 * 60 * 1000
    readonly property int retryFirst: 60 * 1000
    readonly property int requestTimeout: 20 * 1000

    // WMO weather interpretation codes, as Open-Meteo documents them.
    function describe(value: int): string {
        if (value === 0)
            return "Clear";
        if (value === 1)
            return "Mainly clear";
        if (value === 2)
            return "Partly cloudy";
        if (value === 3)
            return "Overcast";
        if (value === 45 || value === 48)
            return "Fog";
        if (value >= 51 && value <= 55)
            return "Drizzle";
        if (value === 56 || value === 57)
            return "Freezing drizzle";
        if (value === 61)
            return "Light rain";
        if (value === 63)
            return "Rain";
        if (value === 65)
            return "Heavy rain";
        if (value === 66 || value === 67)
            return "Freezing rain";
        if (value >= 71 && value <= 75)
            return "Snow";
        if (value === 77)
            return "Snow grains";
        if (value >= 80 && value <= 82)
            return "Showers";
        if (value === 85 || value === 86)
            return "Snow showers";
        if (value === 95)
            return "Thunderstorm";
        if (value === 96 || value === 99)
            return "Thunderstorm, hail";
        return "";
    }

    // The small icon set the widgets draw: clear-day, clear-night, partly-cloudy-day,
    // partly-cloudy-night, cloudy, fog, drizzle, rain, snow, thunderstorm.
    function iconFor(value: int, day: bool): string {
        if (value < 0)
            return "";
        if (value === 0 || value === 1)
            return day ? "clear-day" : "clear-night";
        if (value === 2)
            return day ? "partly-cloudy-day" : "partly-cloudy-night";
        if (value === 3)
            return "cloudy";
        if (value === 45 || value === 48)
            return "fog";
        if (value >= 51 && value <= 57)
            return "drizzle";
        if ((value >= 61 && value <= 67) || (value >= 80 && value <= 82))
            return "rain";
        if ((value >= 71 && value <= 77) || value === 85 || value === 86)
            return "snow";
        if (value >= 95)
            return "thunderstorm";
        return "cloudy";
    }

    function refresh() {
        locate();
        fetch();
    }

    function locate() {
        locator.running = true;
    }

    function useLocation(lat: real, lon: real, source: string) {
        latitude = lat;
        longitude = lon;
        internal.locationSource = source;
    }

    function lastNumber(text: string, label: string): real {
        const pattern = new RegExp("^" + label + ":\\s*(-?[0-9]+[.,][0-9]+)", "gm");
        let value = NaN;
        let match;
        while ((match = pattern.exec(text)) !== null)
            value = Number(match[1].replace(",", "."));
        return value;
    }

    function parseLocation(text: string) {
        // Only the last fix counts; where-am-i prints one per improvement.
        const lat = lastNumber(text, "Latitude");
        const lon = lastNumber(text, "Longitude");
        if (!isFinite(lat) || !isFinite(lon)) {
            locationFailed();
            return;
        }
        const moved = isNaN(latitude) || Math.abs(lat - latitude) > 0.05 || Math.abs(lon - longitude) > 0.05;
        useLocation(lat, lon, "geoclue");
        locationFile.setText(JSON.stringify({
            latitude: lat,
            longitude: lon
        }) + "\n");
        if (moved || !ready)
            fetch();
    }

    function locationFailed() {
        if (!isNaN(latitude))
            return;
        console.warn("Weather: no location from geoclue or the cache; using Nijmegen (" + defaultLatitude + ", " + defaultLongitude + ")");
        useLocation(defaultLatitude, defaultLongitude, "default");
        fetch();
    }

    function parseCache(text: string) {
        if (internal.locationSource === "geoclue")
            return;
        try {
            const cached = JSON.parse(text);
            if (isFinite(cached.latitude) && isFinite(cached.longitude)) {
                useLocation(cached.latitude, cached.longitude, "cache");
                fetch();
            }
        } catch (error) {
            console.warn("Weather: ignoring unreadable " + locationFile.path + ": " + error);
        }
    }

    // A newer fetch replaces one still running; only the current request may
    // report, so an aborted one cannot count as a failure.
    function fetch() {
        if (isNaN(latitude))
            return;
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + latitude.toFixed(2) + "&longitude=" + longitude.toFixed(2) + "&current=temperature_2m,apparent_temperature,weather_code,is_day" + "&hourly=temperature_2m,weather_code,is_day" + "&daily=weather_code,temperature_2m_max,temperature_2m_min" + "&timezone=auto&forecast_days=6&forecast_hours=8";
        const request = new XMLHttpRequest();
        const previous = internal.request;
        internal.request = request;
        if (previous)
            previous.abort();
        request.onreadystatechange = () => {
            if (request.readyState !== XMLHttpRequest.DONE || internal.request !== request)
                return;
            internal.request = null;
            timeout.stop();
            if (request.status !== 200) {
                fetchFailed("Open-Meteo answered " + request.status);
                return;
            }
            try {
                apply(JSON.parse(request.responseText));
            } catch (error) {
                fetchFailed("cannot read the Open-Meteo answer: " + error);
                return;
            }
            failed = false;
            internal.retryDelay = retryFirst;
            retry.stop();
        };
        request.open("GET", url);
        request.send();
        timeout.restart();
    }

    // Retries after a minute, doubling up to the regular interval.
    function fetchFailed(reason: string) {
        console.warn("Weather: " + reason + "; retrying in " + Math.round(internal.retryDelay / 1000) + " s");
        failed = true;
        retry.interval = internal.retryDelay;
        retry.restart();
        internal.retryDelay = Math.min(fetchInterval, internal.retryDelay * 2);
    }

    // Everything is read first, so a malformed answer changes nothing.
    function apply(data: var) {
        const current = data.current;
        if (typeof current.temperature_2m !== "number")
            throw new Error("no current temperature");

        const hours = data.hourly;
        const nextHours = [];
        for (let i = 0; i < hours.time.length && nextHours.length < 5; i++) {
            if (hours.time[i] <= current.time)
                continue;
            nextHours.push({
                time: hours.time[i].slice(11, 16),
                temperature: hours.temperature_2m[i],
                iconName: iconFor(hours.weather_code[i], hours.is_day[i] === 1)
            });
        }

        const days = data.daily;
        const nextDays = [];
        for (let i = 1; i < days.time.length && nextDays.length < 5; i++)
            nextDays.push({
                date: days.time[i],
                max: days.temperature_2m_max[i],
                min: days.temperature_2m_min[i],
                iconName: iconFor(days.weather_code[i], true)
            });

        temperature = current.temperature_2m;
        apparent = current.apparent_temperature;
        code = current.weather_code;
        isDay = current.is_day === 1;
        hourly = nextHours;
        daily = nextDays;
        updated = new Date();
        internal.now = Date.now();
        ready = true;
    }

    Component.onCompleted: locate()

    QtObject {
        id: internal

        // geoclue, cache or default.
        property string locationSource: ""
        property var request: null
        property int retryDelay: root.retryFirst
        property real now: Date.now()
    }

    Timer {
        interval: root.fetchInterval
        repeat: true
        running: true
        onTriggered: root.fetch()
    }

    Timer {
        interval: 60 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.locate()
    }

    Timer {
        id: retry

        onTriggered: root.fetch()
    }

    Timer {
        id: timeout

        interval: root.requestTimeout
        onTriggered: {
            const request = internal.request;
            internal.request = null;
            root.fetchFailed("no answer from Open-Meteo in " + Math.round(root.requestTimeout / 1000) + " s");
            if (request)
                request.abort();
        }
    }

    // A minute clock for `stale`; timers stand still during suspend, so a jump
    // in wall-clock time is a resume and fetches at once.
    Timer {
        interval: 60 * 1000
        repeat: true
        running: true
        onTriggered: {
            const now = Date.now();
            const resumed = now - internal.now > 3 * interval;
            internal.now = now;
            if (resumed)
                root.fetch();
        }
    }

    Connections {
        target: Network

        function onConnectedChanged() {
            if (Network.connected && (root.failed || root.stale || !root.ready))
                root.fetch();
        }
    }

    FileView {
        id: locationFile

        path: root.stateDir + "/weather-location.json"
        printErrors: false
        onLoaded: root.parseCache(text())
    }

    Process {
        command: ["mkdir", "-p", root.stateDir]
        running: true
    }

    // C locale: where-am-i prints the decimal comma of the user's locale otherwise.
    Process {
        id: locator

        command: ["sh", "-c", "[ -x \"$1\" ] || { echo \"where-am-i not found: $1\" >&2; exit 127; }; LC_ALL=C exec \"$1\" -t 10", "sh", root.whereAmI]
        stdout: StdioCollector {
            onStreamFinished: root.parseLocation(text)
        }
    }
}
