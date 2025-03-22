# NordVPN Monitoring Service
This continues to be a work in progress. I am leaving the old service and scripts where they are for now. I have created a new service, script, config file, and install script for the new service.

## Script and service to monitor and manage NordVPN connection

NOTE: NordVPN's auto-connect feature will conflict with this script and needs to be disabled. 

```
nordvpn set autoconnect off
```
# NEW
## install-monitor-service.sh

This script will install the monitoring service using the new versions in the cli-script folder.

Run...
```
bash < <(wget -qO -  https://raw.githubusercontent.com/theOtherLuke/nordlynx-router/refs/heads/main/monitor-script/install-monitor-service.sh)
```
This script will place and configure the following files:
```
./cli-script/connect-nord.sh -> /root/connect-nord.sh
./cli-script/connect-nord.conf -> /root/connect-nord.conf
./cli-script/nordvpn-net-monitor.service -> /etc/systemd/system/nordvpn-net-monitor.service
```
#

## *If you want to use the old service...*
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

    -p : use a p2p server

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
