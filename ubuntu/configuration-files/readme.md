#Ubuntu Configuration Files

##Included are versions to allow various configurations

**NETWORK CONNECTION MANAGEMENT**  

netplan - pre-installed in Ubuntu

  use the config.yaml file

ifupdown + net-tools -

  make the switch using `apt remove netplan* && apt install ifupdown net-tools`

  use the interfaces file


**DHCP SERVER**

kea-dhcp seemed like the logical choice since it appeared not to conflict with systemd-resolved. However, it is significantly more difficult to configure when compared to dnsmasq. It does seem to be quite a bit more powerful, but much of that potential is wasted in this use case. I have opted to get dnsmasq to work instead. If you want to use kea-dhcp:

  use the kea-dhcp4.conf file

If you want a simpler setup, use dnsmasq.

  ```
  systemctl disable --now systemd-resolved
  apt install dnsmaq dnsmasq-utils
  ```

  use the dnsmasq.conf file
