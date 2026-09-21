import QtQuick
import qs.Common
import qs.Services

Row {
    id: stats

    readonly property real tileWidth: (width - spacing * 3) / 4
    readonly property var primaryGpu: DgopService.availableGpus?.[0] ?? null
    readonly property real networkRate: DgopService.networkRxRate + DgopService.networkTxRate

    property var gpuHistory: []
    property var networkSamples: []
    property real networkCeiling: 64
    property int tick: 0

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

    Component.onCompleted: {
        DgopService.addRef(["cpu", "memory", "network"]);
        if (stats.primaryGpu?.pciId) {
            DgopService.addRef(["gpu"]);
            DgopService.addGpuPciId(stats.primaryGpu.pciId);
        }
        stats.refreshNetworkSamples();
    }

    Component.onDestruction: {
        DgopService.removeRef(["cpu", "memory", "network"]);
        if (stats.primaryGpu?.pciId) {
            DgopService.removeRef(["gpu"]);
            DgopService.removeGpuPciId(stats.primaryGpu.pciId);
        }
    }

    StatTile {
        width: stats.tileWidth
        title: I18n.trFor("dotfilesDashboard", "CPU")
        valueText: Math.round(DgopService.cpuUsage) + "%"
        samples: DgopService.cpuHistory
        repaintTrigger: stats.tick
        lineColor: Theme.primary
    }

    StatTile {
        width: stats.tileWidth
        title: I18n.trFor("dotfilesDashboard", "Memory")
        valueText: Math.round(DgopService.memoryUsage) + "%"
        samples: DgopService.memoryHistory
        repaintTrigger: stats.tick
        lineColor: Theme.info
    }

    StatTile {
        width: stats.tileWidth
        title: I18n.trFor("dotfilesDashboard", "GPU")
        valueText: stats.primaryGpu ? Math.round(stats.primaryGpu.temperature) + "°C" : "--"
        samples: stats.gpuHistory
        repaintTrigger: stats.tick
        lineColor: Theme.secondary
    }

    StatTile {
        width: stats.tileWidth
        title: I18n.trFor("dotfilesDashboard", "Network")
        valueText: stats.formatRate(stats.networkRate)
        samples: stats.networkSamples
        sampleCeiling: stats.networkCeiling
        repaintTrigger: stats.tick
        lineColor: Theme.primary
    }

    // dgop mutates its history arrays in place, so nothing notifies on new samples;
    // this timer refreshes the derived data and repaints the sparklines instead.
    Timer {
        interval: 1000
        repeat: true
        running: true
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
            const gpu = stats.primaryGpu;
            if (!gpu)
                return;
            const history = stats.gpuHistory.slice();
            history.push(gpu.temperature || 0);
            if (history.length > 60)
                history.shift();
            stats.gpuHistory = history;
        }
    }
}
