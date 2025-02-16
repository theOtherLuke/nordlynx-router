# CLI Script
I use this script when I want to manage the connection from a terminal. I'm sure you could use this in place of `check-connection.sh` for use with the monitor service. I haven't tried that yet myself.

### connect-nord.conf
This is the settings file for the script. Set your LAN and WAN interfaces, connection options, and logfile name and location here.

### connect-nord.sh
This script is intended to be run from the cli.

Don't forget to make it executable...
```
sudo chmod +x connect-nord.sh
```

Then run it like you would any other script...
```
./connect-nord.sh
```
