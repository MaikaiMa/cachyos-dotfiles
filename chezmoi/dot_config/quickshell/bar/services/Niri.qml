pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Workspaces, windows and focus from Niri's own socket ($NIRI_SOCKET), no `niri msg`.
// One long-lived connection reads the event stream; every action opens a short-lived one.
Singleton {
    id: root

    readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""
    readonly property bool connected: eventSocket !== null && eventSocket.connected

    // Sorted by output, then idx: {id, idx, name, output, isActive, isFocused, isUrgent, activeWindowId}.
    property var workspaces: []
    // Sorted by workspace, column, row: {id, title, appId, workspaceId, isFocused,
    // isFloating, isUrgent, column, row, width, height}; the size is logical.
    property var windows: []
    property int focusedWindowId: -1
    // Niri draws a fullscreen window above the Top layer, so the bar is not
    // visible over it. Niri 26.04 reports no fullscreen flag; a focused window
    // as large as its output's logical size stands in. A windowed fullscreen
    // window is tiled and does not count, and the bar does show over it.
    readonly property bool focusedFullscreen: {
        const window = windows.find(candidate => candidate.id === focusedWindowId);
        const workspace = window ? workspaces.find(candidate => candidate.id === window.workspaceId) : null;
        const screen = workspace ? Quickshell.screens.find(candidate => candidate.name === workspace.output) : null;
        return !!screen && window.width >= screen.width && window.height >= screen.height;
    }
    readonly property var focusedWorkspace: workspaces.find(workspace => workspace.isFocused) ?? null
    readonly property string focusedOutput: focusedWorkspace ? focusedWorkspace.output : ""
    property bool overviewOpen: false
    // Screencasts as Niri reports them: {stream_id, session_id, kind, target,
    // is_dynamic_target, is_active, pid, pw_node_id}; pid and pw_node_id may be null.
    property var casts: []

    // Web apps whose app_id matches no desktop file id; value is an icon name.
    // ChatGPT's desktop file is chatgpt.desktop with Icon=chatgpt (/usr/share/pixmaps).
    property var iconOverrides: ({
            "Chatgpt": "chatgpt"
        })

    // Read by iconFor, so bindings that call it update once the desktop files are scanned.
    readonly property int desktopEntryCount: DesktopEntries.applications.values.length

    property var workspaceById: ({})
    property var windowById: ({})
    property var castById: ({})
    property var eventSocket: null
    property int reconnectDelay: 1000

    function windowsOn(workspaceId: int): var {
        return windows.filter(window => window.workspaceId === workspaceId);
    }

    function iconFor(appId: string): string {
        const fallback = "application-x-executable";
        if (desktopEntryCount < 0)
            return fallback;
        const override = iconOverrides[appId];
        if (override)
            return Quickshell.iconPath(override, fallback);
        const entry = DesktopEntries.byId(appId) ?? DesktopEntries.heuristicLookup(appId);
        return Quickshell.iconPath(entry ? entry.icon : "", fallback);
    }

    // Sends one request on its own connection; callback receives the parsed reply,
    // for instance {"Ok": "Handled"} or {"Err": "..."}, or null when the socket failed.
    function request(message: var, callback: var) {
        if (socketPath === "") {
            console.warn("Niri: NIRI_SOCKET is not set");
            if (callback)
                callback(null);
            return;
        }
        const socket = requestSocketComponent.createObject(root, {
            path: socketPath,
            payload: JSON.stringify(message),
            callback: callback ?? null
        });
        socket.connected = true;
    }

    function action(name: string, args: var) {
        const body = {};
        body[name] = args;
        request({
            "Action": body
        }, reply => {
            if (!reply || reply.Err !== undefined)
                console.warn("Niri: action " + name + " failed: " + JSON.stringify(reply));
        });
    }

    function focusWorkspace(id: int) {
        action("FocusWorkspace", {
            "reference": {
                "Id": id
            }
        });
    }

    function focusWindow(id: int) {
        action("FocusWindow", {
            "id": id
        });
    }

    function toggleOverview() {
        action("ToggleOverview", {});
    }

    function finishRequest(socket: var, reply: var) {
        if (socket.answered)
            return;
        socket.answered = true;
        if (socket.callback)
            socket.callback(reply);
        socket.destroy();
    }

    function connectEvents() {
        if (eventSocket) {
            eventSocket.destroy();
            eventSocket = null;
        }
        if (socketPath === "") {
            console.warn("Niri: NIRI_SOCKET is not set; workspaces stay empty");
            return;
        }
        // Quickshell's Socket cannot redial after a failed attempt, so every attempt gets a new one.
        eventSocket = eventSocketComponent.createObject(root, {
            path: socketPath
        });
        eventSocket.connected = true;
    }

    function scheduleReconnect() {
        if (reconnectTimer.running)
            return;
        reconnectTimer.interval = reconnectDelay;
        reconnectTimer.start();
        reconnectDelay = Math.min(reconnectDelay * 2, 30000);
    }

    function toWorkspace(raw: var): var {
        return {
            id: raw.id,
            idx: raw.idx,
            name: raw.name ?? "",
            output: raw.output ?? "",
            isActive: raw.is_active === true,
            isFocused: raw.is_focused === true,
            isUrgent: raw.is_urgent === true,
            activeWindowId: raw.active_window_id ?? -1
        };
    }

    function toWindow(raw: var): var {
        const position = raw.layout ? raw.layout.pos_in_scrolling_layout : null;
        const size = raw.layout ? raw.layout.window_size : null;
        return {
            id: raw.id,
            title: raw.title ?? "",
            appId: raw.app_id ?? "",
            workspaceId: raw.workspace_id ?? -1,
            isFocused: raw.is_focused === true,
            isFloating: raw.is_floating === true,
            isUrgent: raw.is_urgent === true,
            column: position ? position[0] : -1,
            row: position ? position[1] : -1,
            width: size ? size[0] : 0,
            height: size ? size[1] : 0
        };
    }

    function publishWorkspaces() {
        workspaces = Object.values(workspaceById).sort((a, b) => a.output === b.output ? a.idx - b.idx : a.output.localeCompare(b.output));
    }

    function publishWindows() {
        const order = {};
        workspaces.forEach((workspace, index) => order[workspace.id] = index);
        windows = Object.values(windowById).sort((a, b) => {
            if (a.workspaceId !== b.workspaceId)
                return (order[a.workspaceId] ?? 1e6) - (order[b.workspaceId] ?? 1e6);
            if (a.column !== b.column)
                return a.column - b.column;
            return a.row - b.row;
        });
    }

    function publishCasts() {
        casts = Object.values(castById).sort((a, b) => a.stream_id - b.stream_id);
    }

    function updateWorkspace(id: int, change: var) {
        const workspace = workspaceById[id];
        if (workspace)
            workspaceById[id] = Object.assign({}, workspace, change);
    }

    function setFocusedWindow(id: int) {
        focusedWindowId = id;
        for (const key in windowById)
            windowById[key] = Object.assign({}, windowById[key], {
                isFocused: windowById[key].id === id
            });
    }

    function handleEvent(event: var) {
        if (event.WorkspacesChanged) {
            const next = {};
            for (const raw of event.WorkspacesChanged.workspaces)
                next[raw.id] = toWorkspace(raw);
            workspaceById = next;
            publishWorkspaces();
            publishWindows();
        } else if (event.WorkspaceActivated) {
            const activated = workspaceById[event.WorkspaceActivated.id];
            if (!activated)
                return;
            const focused = event.WorkspaceActivated.focused === true;
            for (const key in workspaceById) {
                const workspace = workspaceById[key];
                const change = {};
                if (workspace.output === activated.output)
                    change.isActive = workspace.id === activated.id;
                if (focused)
                    change.isFocused = workspace.id === activated.id;
                workspaceById[key] = Object.assign({}, workspace, change);
            }
            publishWorkspaces();
        } else if (event.WorkspaceActiveWindowChanged) {
            updateWorkspace(event.WorkspaceActiveWindowChanged.workspace_id, {
                activeWindowId: event.WorkspaceActiveWindowChanged.active_window_id ?? -1
            });
            publishWorkspaces();
        } else if (event.WorkspaceUrgencyChanged) {
            updateWorkspace(event.WorkspaceUrgencyChanged.id, {
                isUrgent: event.WorkspaceUrgencyChanged.urgent === true
            });
            publishWorkspaces();
        } else if (event.WindowsChanged) {
            const next = {};
            let focused = -1;
            for (const raw of event.WindowsChanged.windows) {
                next[raw.id] = toWindow(raw);
                if (raw.is_focused)
                    focused = raw.id;
            }
            windowById = next;
            focusedWindowId = focused;
            publishWindows();
        } else if (event.WindowOpenedOrChanged) {
            const window = toWindow(event.WindowOpenedOrChanged.window);
            windowById[window.id] = window;
            if (window.isFocused)
                setFocusedWindow(window.id);
            publishWindows();
        } else if (event.WindowClosed) {
            delete windowById[event.WindowClosed.id];
            if (focusedWindowId === event.WindowClosed.id)
                focusedWindowId = -1;
            publishWindows();
        } else if (event.WindowFocusChanged) {
            setFocusedWindow(event.WindowFocusChanged.id ?? -1);
            publishWindows();
        } else if (event.WindowLayoutsChanged) {
            for (const change of event.WindowLayoutsChanged.changes) {
                const window = windowById[change[0]];
                const position = change[1] ? change[1].pos_in_scrolling_layout : null;
                const size = change[1] ? change[1].window_size : null;
                if (window)
                    windowById[change[0]] = Object.assign({}, window, {
                        column: position ? position[0] : -1,
                        row: position ? position[1] : -1,
                        width: size ? size[0] : window.width,
                        height: size ? size[1] : window.height
                    });
            }
            publishWindows();
        } else if (event.WindowUrgencyChanged) {
            const window = windowById[event.WindowUrgencyChanged.id];
            if (window)
                windowById[window.id] = Object.assign({}, window, {
                    isUrgent: event.WindowUrgencyChanged.urgent === true
                });
            publishWindows();
        } else if (event.OverviewOpenedOrClosed) {
            overviewOpen = event.OverviewOpenedOrClosed.is_open === true;
        } else if (event.CastsChanged) {
            const next = {};
            for (const cast of event.CastsChanged.casts ?? [])
                next[cast.stream_id] = cast;
            castById = next;
            publishCasts();
        } else if (event.CastStartedOrChanged) {
            const cast = event.CastStartedOrChanged.cast;
            castById[cast.stream_id] = cast;
            publishCasts();
        } else if (event.CastStopped) {
            delete castById[event.CastStopped.stream_id];
            publishCasts();
        }
    }

    function handleEventLine(line: string) {
        if (line === "")
            return;
        let event;
        try {
            event = JSON.parse(line);
        } catch (error) {
            console.warn("Niri: cannot parse event: " + error);
            return;
        }
        // The first reply to "EventStream" is {"Ok": "Handled"}; events follow.
        if (event.Ok !== undefined)
            return;
        if (event.Err !== undefined) {
            console.warn("Niri: event stream refused: " + event.Err);
            return;
        }
        handleEvent(event);
    }

    Component.onCompleted: connectEvents()

    Timer {
        id: reconnectTimer

        onTriggered: root.connectEvents()
    }

    Component {
        id: eventSocketComponent

        Socket {
            id: eventStream

            parser: SplitParser {
                onRead: line => root.handleEventLine(line)
            }
            onConnectionStateChanged: {
                if (eventStream.connected) {
                    root.reconnectDelay = 1000;
                    eventStream.write("\"EventStream\"\n");
                    eventStream.flush();
                } else {
                    console.warn("Niri: event stream closed; reconnecting");
                    root.scheduleReconnect();
                }
            }
            // A failed dial emits only error, never a state change.
            // The error enum lives in QtNetwork, which qmllint cannot see.
            onError: { // qmllint disable signal-handler-parameters
                if (!eventStream.connected)
                    root.scheduleReconnect();
            }
        }
    }

    Component {
        id: requestSocketComponent

        Socket {
            id: requestSocket

            property string payload: ""
            property var callback: null
            property bool answered: false

            parser: SplitParser {
                onRead: line => {
                    let reply = null;
                    try {
                        reply = JSON.parse(line);
                    } catch (error) {
                        console.warn("Niri: cannot parse reply: " + error);
                    }
                    root.finishRequest(requestSocket, reply);
                }
            }
            onConnectionStateChanged: {
                if (requestSocket.connected) {
                    requestSocket.write(requestSocket.payload + "\n");
                    requestSocket.flush();
                } else {
                    root.finishRequest(requestSocket, null);
                }
            }
            onError: root.finishRequest(requestSocket, null) // qmllint disable signal-handler-parameters
        }
    }
}
