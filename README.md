# win_netroute - Adds or removes an IP route in the IP routing table

## Synopsis

* Ansible module to add or remove an IP route in the IP routing table on Windows-based systems.

## Parameters

| Parameter     | Choices/<font color="blue">Defaults</font> | Comments |
| ------------- | ---------|--------- |
|__interface_alias__<br><font color="purple">string</font> |  | Alias of a network interface.<br>The module adds or removes a route for the interface that has the alias that you specify.<br>If _interface_alias_ is not provided and _gateway_ is provided, the module uses the [Find-NetRoute] cmdlet to determine the value of _interface_alias_. |
|__destination__<br><font color="purple">string</font> / <font color="red">required</font> |  | Destination IP address in CIDR format (ip address/prefix length). |
|__gateway__<br><font color="purple">string</font> |  | Gateway used by the static route.<br>If _gateway_ and _interface_alias_ are not provided it will be set to `0.0.0.0`.<br>If _gateway_ is not provided it will be set to the gateway defined for _interface_alias_. |
|__metric__<br><font color="purple">integer</font> | __Default:__<br><font color="blue">1</font> | Metric used by the static route. |
|__state__<br><font color="purple">string</font> | __Choices__: <ul><li>absent</li><li><font color="blue">__present &#x2190;__</font></li></ul> | If `absent`, it removes a network static route.<br>If `present`, it adds a network static route. |

## Examples

```yaml
---
---
  roles:
    - win_netroute

  tasks:

    - name: Add a network static route
      win_netroute:
        interface_alias: eth1
        destination: 192.168.2.10/32
        gateway: 192.168.1.1
        metric: 1
        state: present

    - name: Add a network static route by using the gateway of the network interface
      win_netroute:
        interface_alias: eth1
        destination: 192.168.2.10/32
        metric: 1
        state: present

    - name: Add a network static route by using 0.0.0.0 as gateway
      win_netroute:
        destination: 192.168.2.10/32
        metric: 1
        state: present

    - name: Remove a network static route by using the gateway
      win_netroute:
        destination: 192.168.2.10/32
        state: absent
        gateway: 192.168.1.1

    - name: Remove a network static route by using the interface alias
      win_netroute:
        interface_alias: eth1
        destination: 192.168.2.10/32
        state: absent

    - name: Remove a network static route
      win_netroute:
        destination: 192.168.2.10/32
        state: absent

```

## Return Values

Common return values are documented [here](https://docs.ansible.com/ansible/latest/reference_appendices/common_return_values.html#common-return-values), the following are the fields unique to this module:

| Key    | Returned   | Description |
| ------ |------------| ------------|
|__destination__<br><font color="purple">string</font> | always | The destination IP address in CIDR format.<br><br>__Sample:__<br><font color=blue>192.168.2.10/32</font> |
|__gateway__<br><font color="purple">string</font> | always | The gateway used by the static route.<br><br>__Sample:__<br><font color=blue>192.168.1.1</font> |
|__interface_alias__<br><font color="purple">string</font> | always | The alias of a network interface used for the static route.<br><br>__Sample:__<br><font color=blue>eth1</font> |
|__metric__<br><font color="purple">integer</font> | always | The metric used by the static route.<br><br>__Sample:__<br><font color=blue>16</font> |
|__output__<br><font color="purple">string</font> | always | A message describing the task result.<br><br>__Sample:__<br><font color=blue>Route added</font> |
|__state__<br><font color="purple">string</font> | always | The state of the IP route.<br><br>__Sample:__<br><font color=blue>present</font> |

## Notes

* Works only with Windows 2012 R2 and newer.
* This module is a fork of the [win_route] module.
* This module allows to add or remove a route for the interface that has the alias that you specify.
* This module automatically calculates the gateway as a network interface when it does not have one by default.
* This module allows you to modify the characteristics of a route that already exists (metric, gateway or interface).

## Authors

* Stéphane Bilqué (@sbilque)  - fork of win_route
* Daniele Lazzari (lazzari@mailup.com)- creator of win_route

## License

This project is licensed under the GNU General Public License v3.0 License.

See [LICENSE](LICENSE) to see the full text.
