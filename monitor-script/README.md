# NordVPN Monitoring Service
This continues to be a work in progress. The current version should still continue to be useful. I am continuing to work on this in my spare time, which unfortunately has not been in abundance lately. I am manually running a much simpler script from the CLI for the time being. I will post a version of that as well. As with the rest, feel free to use and modify it as you see fit.

## Script and service to monitor and manage NordVPN connection

NOTE: NordVPN's auto-connect feature will conflict with this script and needs to be disabled. 

```
nordvpn set autoconnect off
```

## check-connection.sh

This script has been rewritten almost from scratch. The changes address some issues I noticed in the initial version. This new version should be more efficient and robust.

Place this script in `/root/`

and make it executable(thanks @Kenny606 for the reminder)

`$ chmod +x /root/check-connection.sh`

The location can be changed. Just make sure to change the location in the .service file to match

### Usage :
  ./check-connection.sh [options]

  options :
  
    -v : increase verbosity of output
  
    -c country : set country to connect in

  Run `nordvpn countries` for a list of countries in which they have servers.

  These options can be used when calling inside nordvpn-net-monitor.service as well.


## nordvpn-net-monitor.service

Place this service in `/etc/systemd/system/`

Reload systemd, enable and start service
```
$ systemctl daemon-reload
$ systemctl enable --now nordvpn-net-monitor
```

Check service status
```
$ systemctl status nordvpn-net-monitor.service
```
