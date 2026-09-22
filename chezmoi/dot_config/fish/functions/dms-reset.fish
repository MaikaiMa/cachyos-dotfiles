function dms-reset --description 'Restart the DankMaterialShell systemd user service; see ADR-0007'
    systemctl --user restart dms.service
    and systemctl --user --no-pager --lines=0 status dms.service
end
