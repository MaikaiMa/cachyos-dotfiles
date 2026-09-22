import QtQuick
import qs.Common
import qs.Services

Row {
    id: stats

    property var popout: null

    readonly property int processesTab: 0
    readonly property int performanceTab: 1

    // DMS keeps plugin popout content loaded after close, so everything periodic here
    // has to follow the popout's visibility instead of running for the session.
    property bool popoutVisible: false

    readonly property real tileWidth: (width - spacing * 3) / 4
    readonly property var primaryGpu: DgopService.availableGpus?.[0] ?? null
    readonly property real networkRate: DgopService.networkRxRate + DgopService.networkTxRate

    property var gpuHistory: []
    property var networkSamples: []
    property real networkCeiling: 64
    property int tick: 0

    property bool baseRefHeld: false
    property string gpuRefPciId: ""

    // Releasing the last reference to a pciId makes dgop rewrite availableGpus, which
    // re-enters the handler below, so the bookkeeping is cleared before the call and
    // syncGpuRef refuses to run inside itself.
    property bool syncingGpuRef: false

    function releaseGpuRef() {
        const pciId = stats.gpuRefPciId;
        if (pciId === "")
            return;

        stats.gpuRefPciId = "";
        DgopService.removeRef(["gpu"]);
        DgopService.removeGpuPciId(pciId);
    }

    function syncGpuRef() {
        if (stats.syncingGpuRef)
            return;

        stats.syncingGpuRef = true;
        const wanted = stats.popoutVisible ? (stats.primaryGpu?.pciId ?? "") : "";
        if (stats.gpuRefPciId !== wanted) {
            stats.releaseGpuRef();
            if (wanted !== "") {
                DgopService.addRef(["gpu"]);
                DgopService.addGpuPciId(wanted);
                stats.gpuRefPciId = wanted;
            }
        }
        stats.syncingGpuRef = false;
    }

    function syncDgopRefs() {
        if (stats.popoutVisible && !stats.baseRefHeld) {
            DgopService.addRef(["cpu", "memory", "network"]);
            stats.baseRefHeld = true;
        } else if (!stats.popoutVisible && stats.baseRefHeld) {
            DgopService.removeRef(["cpu", "memory", "network"]);
            stats.baseRefHeld = false;
        }
        stats.syncGpuRef();
    }

    function openProcessList(tab, sortBy) {
        stats.popout?.closePopout();
        if (sortBy)
            DgopService.setSortBy(sortBy);

        const modal = PopoutService.processListModal;
        if (modal) {
            modal.currentTab = tab;
            modal.focusOrToggle();
            return;
        }

        PopoutService.showProcessListModal();
        Qt.callLater(() => {
            const loaded = PopoutService.processListModal;
            if (loaded)
                loaded.currentTab = tab;
        });
    }

    function formatRate(bytesPerSecond) {
        const rate = bytesPerSecond || 0;
        if (rate < 1024)
            return Math.round(rate) + " B/s";
        if (rate < 1024 * 1024)
            return Math.round(rate / 1024) + " kB/s";
        return (rate / (1024 * 1024)).toFixed(1) + " MB/s";
    }

    function refreshNetworkSamples() {
        const rx = DgopService.networkHistory?.rx ?? [];
        const tx = DgopService.networkHistory?.tx ?? [];
        const merged = [];
        let peak = 64;
        for (let index = 0; index < rx.length; index++) {
            const value = (rx[index] || 0) + (tx[index] || 0);
            peak = Math.max(peak, value);
            merged.push(value);
        }
        networkSamples = merged;
        networkCeiling = peak;
    }

    spacing: Theme.spacingS

    onPopoutVisibleChanged: stats.syncDgopRefs()

    Component.onCompleted: {
        stats.syncDgopRefs();
        stats.refreshNetworkSamples();
    }

    Component.onDestruction: {
        stats.releaseGpuRef();
        if (stats.baseRefHeld) {
            DgopService.removeRef(["cpu", "memory", "network"]);
            stats.baseRefHeld = false;
        }
    }

    StatTile {
        width: stats.tileWidth
        title: I18n.trFor("dotfilesDashboard", "CPU")
        valueText: Math.round(DgopService.cpuUsage) + "%"
        samples: DgopService.cpuHistory
        repaintTrigger: stats.tick
        lineColor: Theme.primary
        onClicked: stats.openProcessList(stats.processesTab, "cpu")
    }

    StatTile {
        width: stats.tileWidth
        title: I18n.trFor("dotfilesDashboard", "Memory")
        valueText: Math.round(DgopService.memoryUsage) + "%"
        samples: DgopService.memoryHistory
        repaintTrigger: stats.tick
        lineColor: Theme.info
        onClicked: stats.openProcessList(stats.processesTab, "memory")
    }

    StatTile {
        width: stats.tileWidth
        title: I18n.trFor("dotfilesDashboard", "GPU")
        valueText: stats.primaryGpu ? Math.round(stats.primaryGpu.temperature) + "°C" : "--"
        samples: stats.gpuHistory
        repaintTrigger: stats.tick
        lineColor: Theme.secondary
        onClicked: stats.openProcessList(stats.performanceTab, "")
    }

    StatTile {
        width: stats.tileWidth
        title: I18n.trFor("dotfilesDashboard", "Network")
        valueText: stats.formatRate(stats.networkRate)
        samples: stats.networkSamples
        sampleCeiling: stats.networkCeiling
        repaintTrigger: stats.tick
        lineColor: Theme.primary
        onClicked: stats.openProcessList(stats.performanceTab, "")
    }

    // dgop mutates its history arrays in place, so nothing notifies on new samples;
    // this timer refreshes the derived data and repaints the sparklines instead.
    Timer {
        interval: 1000
        repeat: true
        running: stats.popoutVisible
        onTriggered: {
            stats.refreshNetworkSamples();
            stats.tick++;
        }
    }

    // dgop reports GPU temperature but no utilisation and keeps no GPU history,
    // so the GPU sparkline is sampled here while the popout is open.
    Connections {
        target: DgopService

        function onAvailableGpusChanged() {
            stats.syncGpuRef();

            const gpu = stats.primaryGpu;
            if (!gpu || !stats.popoutVisible)
                return;
            const history = stats.gpuHistory.slice();
            history.push(gpu.temperature || 0);
            if (history.length > 60)
                history.shift();
            stats.gpuHistory = history;
        }
    }
}
