.pragma library

// Copy-on-write for the services' map properties: a binding sees a change
// only when the property gets a new object.

function withKey(map, key, value) {
    const next = Object.assign({}, map);
    next[key] = value;
    return next;
}

function withoutKey(map, key) {
    const next = Object.assign({}, map);
    delete next[key];
    return next;
}
