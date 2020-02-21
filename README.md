# win_netroute - Adds or removes an IP route in the IP routing table

## Synopsys

* Ansible module to add or remove an IP route in the IP routing table on Windows-based systems.

## Features

* This module is a fork of the `win_route` module.
* This module allows to add or remove a route for the interface that has the alias that you specify.
* This module automatically calculates the gateway as a network interface when it does not have one by default.
* This module allows you to modify the characteristics of a route that already exists (metric, gateway or interface).

## Parameters

| Parameter       | Required | Choices/Default                                              | Comments                                                                                                                                                                                                                                                                                     |
| --------------- | -------- | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| interface_alias | no       |                                                              | - Alias of a network interface.<br>- The module adds or removes a route for the interface that has the alias that you specify.<br>- If `interface_alias` is not provided and `gateway` is provided, the module uses the `Find-NetRoute` cmdlet to determine the value of  `interface_alias`. |
| destination     | yes      |                                                              | Destination IP address in CIDR format (ip address/prefix length).                                                                                                                                                                                                                            |
| gateway         | no       | Default: `0.0.0.0`                                           | - Gateway used by the static route.<br>- If `gateway` and `interface_alias` are not provided it will be set to `0.0.0.0`.<br>- If `gateway` is not provided it will be set to the gateway defined for `interface_alias`.                                                                     |
| metric          | no       | Default: `1`                                                 | Metric used by the static route.                                                                                                                                                                                                                                                             |
| state           | no       | Choices: <ul> <li>`present` <-</li>  <li>`absent`</li> </ul> | - If `absent`, it removes a network static route.<br>      - If `present`, it adds a network static route.                                                                                                                                                                                   |

## Notes

* Works only with Windows 2012 R2 and newer.

## Examples

```yaml
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

The following are the fields unique to this module:

| Key             | Description                                                 | Returned | Type | Example           |
| --------------- | ----------------------------------------------------------- | -------: | ---- | ----------------- |
| destination     | The destination IP address in CIDR format.                  |   always | str  | "192.168.2.10/32" |
| gateway         | The gateway used by the static route.                       |   always | str  | "192.168.1.1"     |
| interface_alias | The alias of a network interface used for the static route. |   always | str  | "eth1"            |
| metric          | The metric used by the static route.                        |   always | int  | 16                |
| output          | A message describing the task result.                       |   always | str  | "Route added"     |
| state           | The state of the IP route.                                  |   always | str  | "present"         |

## License

GNU General Public License v3.0

See [LICENSE](LICENSE) to see the full text.

## Author Information

* [Daniele Lazzari (lazzari@mailup.com)](mailto:lazzari@mailup.com) - *creator of win_route*
* [Stéphane Bilqué](https://github.com/sbilque)  - *fork of win_route*
  