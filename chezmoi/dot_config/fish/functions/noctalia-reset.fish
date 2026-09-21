function noctalia-reset --description 'Restart the Noctalia systemd user service; see ADR-0007'
    systemctl --user restart noctalia.service
    and systemctl --user --no-pager --lines=0 status noctalia.service
end
