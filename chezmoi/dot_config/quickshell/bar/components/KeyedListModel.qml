import QtQuick

// A ListModel patched by key instead of replaced, so a row keeps its delegate
// (a dragged capsule, a half-typed password, a running animation) while rows
// come, go and move. sync(keys, entryFor) brings the rows to the keys' order;
// entryFor(key), when given, returns a new row's other roles, and with
// refresh the rows that stay take them again on every sync.
//
// With leavingRoles a key that goes keeps its row, marked with the first of
// these roles or the one leavingRole(key) names, until the owner calls
// finish(key) once the row's leave animation is done. Then rows never move: a
// new key is inserted at its position among the keys, or with newAtTop above
// every row.
ListModel {
    id: model

    property string keyRole: "rowKey"
    property var leavingRoles: []
    property bool refresh: false
    property bool newAtTop: false
    // Rows that are not leaving, and the index after the last of them;
    // updated by sync and finish.
    property int settledCount: 0
    property int settledEnd: 0

    function keyAt(index: int): string {
        return get(index)[keyRole];
    }

    function leavingAt(index: int): bool {
        const row = get(index);
        return leavingRoles.some(role => row[role]);
    }

    // The row of a key that is not leaving, or -1.
    function indexOf(key: string): int {
        for (let index = 0; index < count; index++) {
            if (keyAt(index) === key && !leavingAt(index))
                return index;
        }
        return -1;
    }

    function rowFor(key: string, entryFor: var): var {
        const row = entryFor ? entryFor(key) : {};
        row[keyRole] = key;
        for (const role of leavingRoles)
            row[role] = false;
        return row;
    }

    function sync(keys: var, entryFor: var, leavingRole: var) {
        if (leavingRoles.length > 0)
            syncLeaving(keys, entryFor ?? null, leavingRole ?? null);
        else
            syncOrder(keys, entryFor ?? null);
        countSettled();
    }

    function syncOrder(keys: var, entryFor: var) {
        for (let index = count - 1; index >= 0; index--) {
            if (!keys.includes(keyAt(index)))
                remove(index);
        }
        keys.forEach((key, index) => {
            if (index >= count || keyAt(index) !== key) {
                let from = index + 1;
                while (from < count && keyAt(from) !== key)
                    from++;
                if (from >= count) {
                    insert(index, rowFor(key, entryFor));
                    return;
                }
                move(from, index, 1);
            }
            if (refresh)
                set(index, rowFor(key, entryFor));
        });
    }

    function syncLeaving(keys: var, entryFor: var, leavingRole: var) {
        for (let index = 0; index < count; index++) {
            if (!leavingAt(index) && !keys.includes(keyAt(index)))
                setProperty(index, leavingRole ? leavingRole(keyAt(index)) : leavingRoles[0], true);
        }
        if (newAtTop) {
            const missing = keys.filter(key => indexOf(key) < 0);
            for (let position = missing.length - 1; position >= 0; position--)
                insert(0, rowFor(missing[position], entryFor));
            return;
        }
        keys.forEach((key, position) => {
            if (indexOf(key) < 0)
                insert(Math.min(position, count), rowFor(key, entryFor));
        });
    }

    function finish(key: string) {
        for (let index = count - 1; index >= 0; index--) {
            if (keyAt(index) === key && leavingAt(index))
                remove(index);
        }
        countSettled();
    }

    function countSettled() {
        let settled = 0;
        let end = 0;
        for (let index = 0; index < count; index++) {
            if (leavingAt(index))
                continue;
            settled++;
            end = index + 1;
        }
        settledCount = settled;
        settledEnd = end;
    }
}
