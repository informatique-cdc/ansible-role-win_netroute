#!powershell

# Copyright: (c) 2016, Daniele Lazzari <lazzari@mailup.com>
# Copyright: (c) 2020, Informatique CDC

# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy

# win_netroute (Add or remove a network static route)

$params = Parse-Args $args -supports_check_mode $true

$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -default $false
$DestinationPrefix = Get-AnsibleParam -obj $params -name "destination" -type "str" -failifempty $true
$NextHop = Get-AnsibleParam -obj $params -name "gateway" -type "str"
$RouteMetric = Get-AnsibleParam -obj $params -name "metric" -type "int" -default 1
$state = Get-AnsibleParam -obj $params -name "state" -type "str" -default "present" -validateSet "present", "absent"
$interfaceAlias = Get-AnsibleParam -obj $params -name "interface_alias" -type "str"

$result = @{
  "changed" = $false
  "output"  = ""
}
function toBinary ($dottedDecimal) {
  $dottedDecimal.split(".") | Foreach-object { $binary = $binary + $([convert]::toString($_, 2).padleft(8, "0")) }
  return $binary
}
function toDottedDecimal ($binary) {
  do { $dottedDecimal += "." + [string]$([convert]::toInt32($binary.substring($i, 8), 2)); $i += 8 } while ($i -le 24)
  return $dottedDecimal.substring(1)
}

function Get-DefaultGateway {
  param(
    [Parameter(Mandatory = $true)]
    [string]$InterfaceAlias
  )

  $IpConfiguration = Get-NetIPConfiguration -InterfaceAlias $InterfaceAlias

  $DefaultGateway = $IpConfiguration.IPv4DefaultGateway.NextHop

  if ($DefaultGateway) {
    return $DefaultGateway
  }

  $ipaddresses = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4
  $IPAddress = $ipaddresses[0].IPAddress
  $prefix = $ipaddresses[0].PrefixLength

  $subnetMask = '{0}.{1}.{2}.{3}' -f @(
    [math]::Truncate([convert]::ToInt64(('1' * $prefix + '0' * (32 - $prefix)), 2) / 16777216)
    [math]::Truncate([convert]::ToInt64(('1' * $prefix + '0' * (32 - $prefix)), 2) % 16777216 / 65536)
    [math]::Truncate([convert]::ToInt64(('1' * $prefix + '0' * (32 - $prefix)), 2) % 65536 / 256)
    [math]::Truncate([convert]::ToInt64(('1' * $prefix + '0' * (32 - $prefix)), 2) % 256)
  )

  $ipAddressBinary = toBinary -dottedDecimal $IPAddress
  $subnetMaskBinary = toBinary -dottedDecimal $subnetMask
  $netBits = $subnetMaskBinary.indexOf("0")
  $DefaultGateway = toDottedDecimal -binary $($ipAddressBinary.substring(0, $netBits).padright(31, "0") + "1")
  return $DefaultGateway
}

Function Get-Route {
  <#
    .SYNOPSIS
    This function looks up the route using the parameters and returns
    it. If the route is not found $null is returned.
    .PARAMETER InterfaceAlias
    Specifies the alias of a network interface.
    .PARAMETER DestinationPrefix
    Specifies a destination prefix of an IP route.
    A destination prefix consists of an IP address prefix
    and a prefix length, separated by a slash (/).
    .PARAMETER NextHop
    Specifies the next hop for the IP route.
#>
  Param (
    [Parameter(Mandatory = $false)]
    [string]$InterfaceAlias,
    [Parameter(Mandatory = $true)]
    [string]$DestinationPrefix,
    [Parameter(Mandatory = $true)]
    [string]$NextHop,
    [Parameter(Mandatory = $false)]
    [string]$RouteMetric
  )
  # Remove any parameters that can't be splatted.
  $null = $PSBoundParameters.Remove('RouteMetric')
  $null = $PSBoundParameters.Remove('InterfaceAlias')

  try {
    $route = Get-NetRoute @PSBoundParameters -ErrorAction Stop
  }
  catch [Microsoft.PowerShell.Cmdletization.Cim.CimJobException] {
    $route = $null
  }
  catch {
    throw $_
  }

  $result.interface_alias = $route.InterfaceAlias
  $result.metric = $route.RouteMetric

  return $route
}

Function Test-Route {
  [OutputType([System.Boolean])]
  Param (
    [Parameter(Mandatory = $false)]
    [string]$InterfaceAlias,
    [Parameter(Mandatory = $true)]
    [string]$DestinationPrefix,
    [Parameter(Mandatory = $true)]
    [string]$NextHop,
    [Parameter(Mandatory = $false)]
    [int]$RouteMetric,
    [Parameter(Mandatory = $false)]
    [string]$state = 'present',
    [Parameter(Mandatory = $false)]
    [bool]$checkMode = $false

  )
  $desiredConfigurationMatch = $true

  # Remove any parameters that can't be splatted.
  $null = $PSBoundParameters.Remove('state')
  $null = $PSBoundParameters.Remove('checkMode')

  # Lookup the existing Route
  $route = Get-Route @PSBoundParameters

  if ($state -eq 'present') {
    # The route should exist
    if ($route) {
      # The route exists and does - but check the parameters
      if (($PSBoundParameters.ContainsKey('RouteMetric')) `
          -and ($route.RouteMetric -ne $RouteMetric)) {
        $desiredConfigurationMatch = $false
      }
      if (($PSBoundParameters.ContainsKey('InterfaceAlias')) `
          -and ($route.InterfaceAlias -ne $InterfaceAlias)) {
        $desiredConfigurationMatch = $false
      }
      if (($PSBoundParameters.ContainsKey('NextHop')) `
          -and ($route.NextHop -ne $NextHop)) {
        $desiredConfigurationMatch = $false
      }
    }
    else {
      # The route doesn't exist but should
      $desiredConfigurationMatch = $false
    }
  }
  else {
    # The route should not exist
    if ($route) {
      $desiredConfigurationMatch = $false
    }
  }
  return $desiredConfigurationMatch
}

Function Set-Route {
  <#
    .SYNOPSIS
    Sets a Route for an interface.
    .PARAMETER InterfaceAlias
    Specifies the alias of a network interface.
    #>
  Param (
    [Parameter(Mandatory = $false)]
    [string]$InterfaceAlias,
    [Parameter(Mandatory = $true)]
    [string]$DestinationPrefix,
    [Parameter(Mandatory = $true)]
    [string]$NextHop,
    [Parameter(Mandatory = $true)]
    [int]$RouteMetric,
    [Parameter(Mandatory = $false)]
    [bool]$CheckMode = $false,
    [Parameter(Mandatory = $true)]
    [ValidateSet('present', 'absent')]
    [string]$state = 'present'
  )

  # Remove any parameters that can't be splatted.
  $null = $PSBoundParameters.Remove('checkmode')
  $null = $PSBoundParameters.Remove('state')

  # Check if the static route is already present
  $route = Get-Route @PSBoundParameters

  if ($state -eq 'present') {
    if ($route) {

      if (($PSBoundParameters.ContainsKey('RouteMetric')) `
          -and ($route.RouteMetric -ne $RouteMetric)) {
        $result.metric = $RouteMetric
      }
      else {
        $result.metric = $route.RouteMetric
      }

      if (($PSBoundParameters.ContainsKey('InterfaceAlias')) `
          -and ($route.InterfaceAlias -ne $InterfaceAlias)) {

        $params = @{
          DestinationPrefix = $route.DestinationPrefix
          InterfaceAlias    = $route.InterfaceAlias
          NextHop           = $route.NextHop
        }
        Remove-NetRoute @params -Confirm:$false -ErrorAction Stop -WhatIf:$CheckMode
        New-NetRoute @PSBoundParameters -ErrorAction Stop -WhatIf:$CheckMode | Out-Null
        $result.interface_alias = $InterfaceAlias
      }
      else {
        Set-NetRoute @PSBoundParameters -Confirm:$false -ErrorAction Stop -WhatIf:$CheckMode
        $result.interface_alias = $route.InterfaceAlias
      }

      $result.changed = $true
      $result.output = "Route updated"
    }
    else {

      try {

        # Find Interface Alias
        if (!($PSBoundParameters.ContainsKey('InterfaceAlias'))) {
          $InterfaceAlias = Find-NetRoute -RemoteIPAddress $NextHop | Select-Object -First 1 -ExpandProperty InterfaceAlias
          $PSBoundParameters.Add('InterfaceAlias', $InterfaceAlias)
        }

        # The Route does not exit - create it
        New-NetRoute @PSBoundParameters -ErrorAction Stop -WhatIf:$CheckMode | Out-Null

        $result.interface_alias = $InterfaceAlias
        $result.metric = $RouteMetric
        $result.changed = $true
        $result.output = "Route added"
      }
      catch {
        $ErrorMessage = $_.Exception.Message
        Fail-Json $result $ErrorMessage
      }
    }
  }
  else {
    if ($route) {
      try {
        Remove-NetRoute @PSBoundParameters -Confirm:$false -ErrorAction Stop -WhatIf:$CheckMode
        $result.changed = $true
        $result.output = "Route removed"
      }
      catch {
        $ErrorMessage = $_.Exception.Message
        Fail-Json $result $ErrorMessage
      }
    }
    else {
      $result.output = "No route to remove"
    }
  }
}

# Set gateway if null
if (!($NextHop)) {
  if (!([string]::IsNullOrEmpty($interfaceAlias))) {
    $NextHop = Get-DefaultGateway -InterfaceAlias $interfaceAlias
  }
  else {
    $NextHop = "0.0.0.0"
  }
}
$result.gateway = $NextHop

$params = @{
  DestinationPrefix = $DestinationPrefix
  NextHop           = $NextHop
  RouteMetric       = $RouteMetric
  state             = $state
  checkMode         = $check_mode
}

$result.state = $state
$result.destination = $DestinationPrefix

if (![string]::IsNullOrEmpty($InterfaceAlias)) {
  $result.interface_alias = $InterfaceAlias
  $params.InterfaceAlias = $InterfaceAlias
}

if (!(Test-Route @params)) {
  Set-Route @params
}

Exit-Json $result