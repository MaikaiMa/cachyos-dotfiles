pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Current weather and a short forecast from Open-Meteo, every 15 minutes.
// Location: geoclue's where-am-i demo; else the last fix cached in
// $XDG_STATE_HOME/dotfiles-bar/weather-location.json; else the fallback in
// Settings.
Singleton {
    id: root

    readonly property string whereAmI: "/usr/lib/geoclue-2.0/demos/where-am-i"

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

    // WMO weather interpretation codes, as Open-Meteo documents them: the
    // text and the icon of the small set the widgets draw (clear and
    // partly-cloudy get -day or -night).
    readonly property var wmo: ({
            "0": ["Clear", "clear"],
            "1": ["Mainly clear", "clear"],
            "2": ["Partly cloudy", "partly-cloudy"],
            "3": ["Overcast", "cloudy"],
            "45": ["Fog", "fog"],
            "48": ["Fog", "fog"],
            "51": ["Drizzle", "drizzle"],
            "53": ["Drizzle", "drizzle"],
            "55": ["Drizzle", "drizzle"],
            "56": ["Freezing drizzle", "drizzle"],
            "57": ["Freezing drizzle", "drizzle"],
            "61": ["Light rain", "rain"],
            "63": ["Rain", "rain"],
            "65": ["Heavy rain", "rain"],
            "66": ["Freezing rain", "rain"],
            "67": ["Freezing rain", "rain"],
            "71": ["Snow", "snow"],
            "73": ["Snow", "snow"],
            "75": ["Snow", "snow"],
            "77": ["Snow grains", "snow"],
            "80": ["Showers", "rain"],
            "81": ["Showers", "rain"],
            "82": ["Showers", "rain"],
            "85": ["Snow showers", "snow"],
            "86": ["Snow showers", "snow"],
            "95": ["Thunderstorm", "thunderstorm"],
            "96": ["Thunderstorm, hail", "thunderstorm"],
            "99": ["Thunderstorm, hail", "thunderstorm"]
        })

    function describe(value: int): string {
        return (wmo[value] ?? [""])[0];
    }

    // "" before the first reading; an unknown code draws as cloudy.
    function iconFor(value: int, day: bool): string {
        if (value < 0)
            return "";
        const icon = (wmo[value] ?? ["", "cloudy"])[1];
        return icon === "clear" || icon === "partly-cloudy" ? icon + (day ? "-day" : "-night") : icon;
    }

    function refresh() {
        locate();
        fetch();
    }

    // Where the coordinates came from: geoclue, cache, fixed or default.
    readonly property string locationSource: internal.locationSource
    // The configured place name, else the coordinates: no service can tell
    // the city without another lookup, and geoclue's fix can be a city away.
    readonly property bool usesSettingsLocation: internal.locationSource === "fixed" || internal.locationSource === "default"
    readonly property string placeText: usesSettingsLocation && Settings.weatherPlace !== "" ? Settings.weatherPlace : isNaN(latitude) ? "" : latitude.toFixed(2) + ", " + longitude.toFixed(2)

    // Settings loads its file after this service has asked once, so a fixed
    // location or new coordinates re-locate when they arrive.
    function locate() {
        if (Settings.weatherFixedLocation) {
            const moved = Math.abs(Settings.weatherLatitude - latitude) > 0.05 || Math.abs(Settings.weatherLongitude - longitude) > 0.05;
            useLocation(Settings.weatherLatitude, Settings.weatherLongitude, "fixed");
            if (moved || !ready)
                fetch();
            return;
        }
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
        console.warn("Weather: no location from geoclue or the cache; using the fallback in settings.json (" + Settings.weatherLatitude + ", " + Settings.weatherLongitude + ")");
        useLocation(Settings.weatherLatitude, Settings.weatherLongitude, "default");
        fetch();
    }

    function parseCache(text: string) {
        if (internal.locationSource === "geoclue" || Settings.weatherFixedLocation)
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
                adopt(JSON.parse(request.responseText));
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
    function adopt(data: var) {
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

    Connections {
        target: Settings

        function onWeatherFixedLocationChanged() {
            root.locate();
        }

        function onWeatherLatitudeChanged() {
            if (Settings.weatherFixedLocation)
                root.locate();
        }

        function onWeatherLongitudeChanged() {
            if (Settings.weatherFixedLocation)
                root.locate();
        }
    }

    QtObject {
        id: internal

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

        path: Paths.barState + "/weather-location.json"
        printErrors: false
        onLoaded: root.parseCache(text())
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
