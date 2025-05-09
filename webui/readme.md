# NordVPN Router - WebUI
#### *2025-05-08*
I have developed a basic webui using node.js and websockets. In the coming weeks I hope to post a working version along with installation instructions.
### Features -
* Pages for status, settings, account, about, and login
* Uses bash scripts on the backend to interact with the service and serve info to the node server
* Login page allows for logging the router in to your NordVPN account
* Settings page allows you to change many of the settings by clicking on the appropriate link for each
* Status page shows current status and updates at regular intervals(5 seconds, configurable in the server.js file)
* Account page shows account info(same as `nordvpn account` but in the webui)
* About page currently only show the nordvpn version

### Future Features -
* Multi-node clustering for managing/monitoring multiple instances
* Ability to change settings requiring additional user input(eg. firewallmark, dns)
* Ability to add/remove whitelist items
* Mobile device friendly page rendering
* and possibly more...
