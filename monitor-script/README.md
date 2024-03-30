# NordVPN Monitoring Service


## Script to monitor and manage NordVPN connection

Place this script in `/root/`

The location can be changed. Just make sure to change the location in the .service file to match


## nordvpn-net-monitor.service

Place this service in `/etc/systemd/system/`

Reload systemd, enable service, and start service
```
$ systemctl daemon-reload
$ systemctl enable --now nordvpn-net-monitor
```

Check service status
```
$ systemctl status nordvpn-net-moniter.service
```
