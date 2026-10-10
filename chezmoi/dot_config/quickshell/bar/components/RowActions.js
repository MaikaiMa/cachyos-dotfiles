.pragma library

// The actions an expanded Wi-Fi or Bluetooth row offers, as ListRow takes
// them: an id the panel acts on, the text, and the tone (accent or danger).

function forget() {
    return {
        id: "forget",
        text: "Forget",
        tone: "danger"
    };
}

function connected() {
    return [
        {
            id: "disconnect",
            text: "Disconnect"
        },
        forget()
    ];
}

function saved() {
    return [
        {
            id: "connect",
            text: "Connect",
            tone: "accent"
        },
        forget()
    ];
}

function discovered() {
    return [
        {
            id: "pair",
            text: "Pair",
            tone: "accent"
        }
    ];
}

// A known network that just failed in a way that may be a stale password.
function suspect() {
    return [forget()];
}
