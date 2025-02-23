# CLI Script
I use this script when I want to manage the connection from a terminal. You can use this in place of `check-connection.sh` for use with the monitor service by passing the `-d` option. This script uses a separate config file `connect-nord.conf` to make changing settings easier and safer.

### connect-nord.conf
This is the settings file for the script. Set your LAN and WAN interfaces, connection options, and logfile name and location here.

### connect-nord.sh
This script may be run from the cli or from a service. If run from a service, use the `-d` option to remove the output formatting.

Don't forget to make it executable...
```
sudo chmod +x connect-nord.sh
```

Then run it like you would any other script...
```
./connect-nord.sh
```
...or from a service
```
...
[Service]
ExecStart=/root/connect-nord.sh -d
...
```
