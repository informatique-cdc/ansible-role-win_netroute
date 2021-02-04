#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2020, Informatique CDC
# Copyright: (c) 2017, Daniele Lazzari <lazzari@mailup.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

# This is a windows documentation stub.  Actual code lives in the .ps1
# file of the same name.

ANSIBLE_METADATA = {'metadata_version': '1.0',
                    'status': ['preview'],
                    'supported_by': 'community'}

DOCUMENTATION = r'''
---
module: win_netroute
version_added: "2.6"
short_description: Adds or removes an IP route in the IP routing table
description:
    - Ansible module to add or remove an IP route in the IP routing table on Windows-based systems.
options:
    interface_alias:
      description:
          - Alias of a network interface.
          - The module adds or removes a route for the interface that has the alias that you specify.
          - If I(interface_alias) is not provided and I(gateway) is provided, the module uses the M(Find-NetRoute) cmdlet to determine the value of I(interface_alias).
      type: str
    destination:
        description:
          - Destination IP address in CIDR format (ip address/prefix length).
        type: str
        required: yes
    gateway:
        description:
            - Gateway used by the static route.
            - If I(gateway) and I(interface_alias) are not provided it will be set to C(0.0.0.0).
            - If I(gateway) is not provided it will be set to the gateway defined for I(interface_alias).
        type: str
    metric:
        description:
            - Metric used by the static route.
        type: int
        default: 1
    state:
        description:
          - If C(absent), it removes a network static route.
          - If C(present), it adds a network static route.
        type: str
        choices: [ absent, present ]
        default: present
notes:
    - Works only with Windows 2012 R2 and newer.
    - This module is a fork of the M(win_route) module.
    - This module allows to add or remove a route for the interface that has the alias that you specify.
    - This module automatically calculates the gateway as a network interface when it does not have one by default.
    - This module allows you to modify the characteristics of a route that already exists (metric, gateway or interface).
author:
    - Stéphane Bilqué (@sbilque)  - fork of win_route
    - Daniele Lazzari (lazzari@mailup.com)- creator of win_route
'''

EXAMPLES = r'''
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
'''
RETURN = r'''
destination:
    description: The destination IP address in CIDR format.
    returned: always
    type: str
    sample: "192.168.2.10/32"
gateway:
    description: The gateway used by the static route.
    returned: always
    type: str
    sample: "192.168.1.1"
interface_alias:
    description: The alias of a network interface used for the static route.
    returned: always
    type: str
    sample: "eth1"
metric:
    description: The metric used by the static route.
    returned: always
    type: int
    sample: 16
output:
    description: A message describing the task result.
    returned: always
    type: str
    sample: "Route added"
state:
    description: The state of the IP route.
    returned: always
    type: str
    sample: "present"
'''