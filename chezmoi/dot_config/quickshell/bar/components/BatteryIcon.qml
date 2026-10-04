import QtQuick
import ".."
import "../services"

// The battery glyph for the current charge and state, red when low.
Icon {
    name: {
        if (!Battery.available)
            return "";
        if (Battery.state === "charging")
            return "battery_charging_full";
        if (Battery.isLow && Battery.state === "discharging")
            return "battery_alert";
        if (Battery.percentage >= 95)
            return "battery_full";
        return "battery_" + Math.min(6, Math.max(1, Math.round(Battery.percentage / 100 * 6))) + "_bar";
    }
    color: Battery.isLow ? Colors.error : Colors.foreground
}
