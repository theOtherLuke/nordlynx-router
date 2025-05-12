# /etc/issue and .bashrc
These file are for updating the .bashrc and /etc/issue files.

## update-issue
* **update-issue**
  
  Place in `/usr/local/bin/`. Used with `update-issue.service`

  Run manually to update `/etc/issue` with current LAN IP address.
  
* **update-issue.path**
  
  Place in `/etc/systemd/system/`

  Enable with
  ```
  systemctl daemon-reload
  systemctl enable update-issue.path
  ```

  Watches for IP address changes and runs `update-issue` when an ip address changes.
  
* **update-issue.service**
  
  Place in `/etc/systemd/system/`

  Enable with
  ```
  systemctl daemon-reload
  systemctl enable update-issue.path
  ```
  ...to run at boot. This is not needed since `update-issue.path` calls this when an ip address changes anyways.

* **issue**
  
  Old static `/etc/issue/` file. Previously installed as part of the router setup.
  
## .bashrc
  Append this to your `.bashrc` for some NordVPN Router cli refinements(very minimal)

  Adds a simple ascii art logo and network interfaces with their current ip addresses
