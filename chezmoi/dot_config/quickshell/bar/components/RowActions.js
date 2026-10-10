.pragma library

// The actions an expanded Wi-Fi or Bluetooth row offers, as NetworkRow takes
// them: a key the panel acts on, the label, and accent or danger.

function forget() {
    return {
        key: "forget",
        label: "Forget",
        danger: true
    };
}

function connected() {
    return [
        {
            key: "disconnect",
            label: "Disconnect"
        },
        forget()
    ];
}

function saved() {
    return [
        {
            key: "connect",
            label: "Connect",
            accent: true
        },
        forget()
    ];
}

function discovered() {
    return [
        {
            key: "pair",
            label: "Pair",
            accent: true
        }
    ];
}

// A known network that just failed in a way that may be a stale password.
function suspect() {
    return [forget()];
}
