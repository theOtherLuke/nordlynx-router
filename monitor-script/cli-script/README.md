# CLI Script
I use this script when I want to manage the connection from a terminal. You can use this in place of `check-connection.sh` for use with the monitor service by passing the `-d` option. This script uses a separate config file `connect-nord.conf` to make changing settings easier and safer.

I have also added a service file to use with `connect-nord.sh`.
#
- ### connect-nord.conf
This is the settings file for the script. Set your LAN and WAN interfaces, connection options, and logfile name and location here.
#
- ### connect-nord.sh
This script may be run from the cli or from a service. If run from a service, use the `-d` option to remove the output formatting.

Don't forget to make it executable...
```
sudo chmod +x connect-nord.sh
```

Then run it like you would any other script...
```
./connect-nord.sh
```
Press 'q' to exit the script.

...or from a service
```
...
[Service]
ExecStart=/root/connect-nord.sh -d
...
ExecStop=cat /root/.monitor.pid | xargs -I{} kill{}
...
```
#
- ### nordvpn-net-monitor.service *(alternate monitor service)*
Use this service instead of the main version if using connect-nord.sh

Place this file in `etc/systemd/system/`

then enable it...
```
systemctl daemon-reload
systemctl enable --now nordvpn-net-monitor-service
```
#
- ### monitor.sh
This script simply runs from the cli and displays the current state of the connection and settings. This does not affect the connection in any way.

Don't forget to make it executable...
```
sudo chmod +x connect-nord.sh
```
Then run it...
```
./monitor.sh
```
Press 'q' to exit the script.
