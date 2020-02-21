# Set $ErrorActionPreference to what's set during Ansible execution
$ErrorActionPreference = "Stop"

#Get Current Directory
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path

#Get Function Name
$moduleName = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -Replace ".Tests.ps1"

#Resolve Path to Module path
$ansibleModulePath = "$Here\..\..\library\$moduleName.ps1"

function Get-RequiredModules {
    param (
        [parameter(ValueFromPipeline)]
        [string]$Path
    )
    $content = get-content -path $Path
    $module_pattern = [Regex]"(?im)#Requires -Module (?<module>[a-z.]*)"
    $modules_matches = $module_pattern.Matches($content)
    foreach ($match in $modules_matches) {
        $match.Groups["module"].Value
    }
}

function Get-AnsibleModuleUtils {
    param (
        [parameter(ValueFromPipeline)]
        [string[]]$name
    )
    begin {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }

    process {
        $moduleName = $_
        $ModulePath = "$Here\$moduleName.psm1"
        if (!(Test-Path -Path $ModulePath)) {
            $url = "https://raw.githubusercontent.com/ansible/ansible/stable-2.8/lib/ansible/module_utils/powershell/$moduleName.psm1"
            $output = "$Here\$moduleName.psm1"
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($url, $output)
        }
        Import-Module -Name $ModulePath
    }
}

Function New-ExitJson($obj) {
    <#
    .SYNOPSIS
    Helper function to convert a PowerShell object to JSON and output it, exiting
    the script
    .EXAMPLE
    Exit-Json $result
#>

    # If the provided $obj is undefined, define one to be nice
    If (-not $obj.GetType) {
        $obj = @{ }
    }

    if (-not $obj.ContainsKey('changed')) {
        Set-Attr $obj "changed" $false
    }
    $obj
}

function Invoke-TestSetup {
    $ModuleUtils = Get-RequiredModules -Path $ansibleModulePath 
    $ModuleUtils | Get-AnsibleModuleUtils
    If (Test-Path Alias:Exit-Json) { Remove-Item Alias:Exit-Json }
    Set-Alias -Name Exit-Json -Value New-ExitJson -Scope Global
}    

function Invoke-TestCleanup {
    $ModuleUtils = Get-RequiredModules -Path $ansibleModulePath
    $ModuleUtils | Remove-Module
    If (Test-Path Alias:Exit-Json) { Remove-Item Alias:Exit-Json }
}

Invoke-TestSetup

Function Invoke-AnsibleModule {
    [CmdletBinding()]
    Param(
        [hashtable]$params
    )

    begin {
        $global:complex_args = @{
            "_ansible_check_mode" = $false
            "_ansible_diff"       = $false
        } + $params
    }
    Process {
        . $ansibleModulePath
    }
}

try {

    $mockNetAdapter = [PSCustomObject] @{
        Name            = 'Ethernet'
        IPAddress       = @(
            @{
                IPAddress    = '192.168.1.130'
                PrefixLength = 26
            },
            @{
                IPAddress    = $null
                PrefixLength = $null 
            })
        IPConfiguration = @{
            IPv4DefaultGateway = @{
                NextHop = '192.168.1.129'   
            }
        }    
    }

    $testRoute = @{
        interface_alias = $mockNetAdapter.Name
        state           = 'present'
        destination     = '192.168.2.10/32'
        gateway         = '192.168.1.1'
        metric          = 256
    }

    $defaultValues = @{
        gateway = '0.0.0.0'
        metric  = 1
    }
    
    $mockRoute = @{
        InterfaceAlias    = $mockNetAdapter.Name
        DestinationPrefix = $testRoute.destination 
        NextHop           = $testRoute.gateway
        RouteMetric       = $testRoute.metric
    }

    Describe 'win_netroute' -Tag 'Get' {
        Context 'Route does not exist' {
            Mock -CommandName Get-NetRoute

            $testRouteAbsent = @{
                state       = 'absent'
                destination = '192.168.2.10/32'
                gateway     = '192.168.1.1'
            }

            It 'Should return absent Route' {
                $result = Invoke-AnsibleModule -params $testRouteAbsent
                $result.state | Should -Be 'Absent'
            }
        }

        Context 'Route does exist' {
            Mock -CommandName Get-NetRoute -MockWith { $mockRoute }

            $testRouteExists = @{
                destination = $testRoute.destination
                gateway     = $testRoute.gateway
                metric      = $testRoute.metric
            }

            It 'Should return correct Route' {
                $result = Invoke-AnsibleModule -params $testRouteExists
                $result.state | Should -Be 'Present'
                $result.interface_alias | Should -Be $testRoute.interface_alias
                $result.destination | Should -Be $testRoute.destination
                $result.gateway | Should -Be $testRoute.gateway
                $result.metric | Should -Be $testRoute.metric
            }
        }
    }

    Describe 'win_netroute' -Tag 'Set' {
        Context 'Route does not exist but should' {
            Mock -CommandName Find-NetRoute { 
                return [pscustomobject]@{ InterfaceAlias = $testRoute.interface_alias } 
            }
            Mock -CommandName Remove-NetRoute
            Mock -CommandName New-NetRoute
            Mock -CommandName Set-NetRoute
            Mock -CommandName Get-NetIPConfiguration { return $mockNetAdapter.IPConfiguration }
            Mock -CommandName Get-NetIPAddress { return $mockNetAdapter.IPAddress }
            Mock -CommandName Get-NetRoute

            It 'new route with destination only' {

                Mock -CommandName Find-NetRoute { 
                    return [pscustomobject]@{ InterfaceAlias = 'Ethernet3' } 
                }
                
                $testRouteNew = @{
                    destination = $testRoute.destination
                }
                { $script:result = Invoke-AnsibleModule -params $testRouteNew
                } | Should -Not -Throw
                $script:result.changed | Should -Be $true
                $script:result.output | Should -Be 'Route added'
                $script:result.state | Should -Be 'Present'
                $script:result.interface_alias | Should -Be 'Ethernet3'
                $script:result.destination | Should -Be $testRouteNew.destination
                $script:result.gateway | Should -Be $defaultValues.gateway
                $script:result.metric | Should -Be $defaultValues.metric               
            }

            Mock -CommandName Find-NetRoute { 
                return [pscustomobject]@{ InterfaceAlias = $testRoute.interface_alias } 
            }

            It 'new route with destination and gateway' {

                $testRouteNew = @{
                    destination = $testRoute.destination
                    gateway     = $testRoute.gateway
                }
                { $script:result = Invoke-AnsibleModule -params $testRouteNew
                } | Should -Not -Throw
                $script:result.changed | Should -Be $true
                $script:result.output | Should -Be 'Route added'
                $script:result.state | Should -Be 'Present'
                $script:result.interface_alias | Should -Be $testRoute.interface_alias
                $script:result.destination | Should -Be $testRouteNew.destination
                $script:result.gateway | Should -Be $testRouteNew.gateway
                $script:result.metric | Should -Be $defaultValues.metric               
            }

            It 'new route with destination, gateway and metric' {
                
                $testRouteNew = @{
                    destination = $testRoute.destination
                    gateway     = $testRoute.gateway
                    metric      = $testRoute.metric
                }
                { $script:result = Invoke-AnsibleModule -params $testRouteNew
                } | Should -Not -Throw
                $script:result.changed | Should -Be $true
                $script:result.output | Should -Be 'Route added'
                $script:result.state | Should -Be 'Present'
                $script:result.destination | Should -Be $testRouteNew.destination
                $script:result.gateway | Should -Be $testRouteNew.gateway
                $script:result.metric | Should -Be $testRouteNew.metric               
            }

            It 'new route with destination, gateway, metric and interface_alias' {
                $testRouteNew = @{
                    interface_alias = $testRoute.interface_alias
                    destination     = $testRoute.destination
                    gateway         = $testRoute.gateway
                    metric          = $testRoute.metric
                }
                { $script:result = Invoke-AnsibleModule -params $testRouteNew } | Should -Not -Throw
                $script:result.changed | Should -Be $true
                $script:result.output | Should -Be 'Route added'
                $script:result.state | Should -Be 'Present'
                $script:result.interface_alias | Should -Be $testRouteNew.interface_alias
                $script:result.destination | Should -Be $testRouteNew.destination
                $script:result.gateway | Should -Be $testRouteNew.gateway
                $script:result.metric | Should -Be $testRouteNew.metric                
            }

            It 'new route with destination and interface_alias. interface have gateway' {
                $testRouteNew = @{
                    interface_alias = $testRoute.interface_alias
                    destination     = $testRoute.destination
                }
                { $script:result = Invoke-AnsibleModule -params $testRouteNew } | Should -Not -Throw
                $script:result.changed | Should -Be $true
                $script:result.output | Should -Be 'Route added'
                $script:result.state | Should -Be 'Present'
                $script:result.interface_alias | Should -Be $testRouteNew.interface_alias
                $script:result.destination | Should -Be $testRouteNew.destination
                $script:result.gateway | Should -Be $mockNetAdapter.IPConfiguration.IPv4DefaultGateway.NextHop
                $script:result.metric | Should -Be $defaultValues.metric              
            }

            It 'new route with destination and interface_alias. interface have no gateway' {
                
                Mock -CommandName Get-NetIPConfiguration { 
                    return [PSCustomObject] @{
                        IPv4DefaultGateway = @{
                            NextHop = $null   
                        }    
                    } }

                $testRouteNew = @{
                    interface_alias = $testRoute.interface_alias
                    destination     = $testRoute.destination
                }
                { $script:result = Invoke-AnsibleModule -params $testRouteNew } | Should -Not -Throw
                $script:result.changed | Should -Be $true
                $script:result.output | Should -Be 'Route added'
                $script:result.state | Should -Be 'Present'
                $script:result.interface_alias | Should -Be $testRouteNew.interface_alias
                $script:result.destination | Should -Be $testRouteNew.destination
                $script:result.gateway | Should -Be $mockNetAdapter.IPConfiguration.IPv4DefaultGateway.NextHop
                $script:result.metric | Should -Be $defaultValues.metric              
            }
        }

        Context 'Route exists but should be updated' {
            Mock -CommandName Remove-NetRoute
            Mock -CommandName New-NetRoute
            Mock -CommandName Get-NetIPConfiguration { return $mockNetAdapter.IPConfiguration }
            Mock -CommandName Get-NetIPAddress { return $mockNetAdapter.IPAddress }
            Mock -CommandName Set-NetRoute

            $testRouteNew = @{
                interface_alias = $testRoute.interface_alias
                destination     = $testRoute.destination
                gateway         = $testRoute.gateway
                metric          = $testRoute.metric
            }

            It 'interface_alias should be updated' {

                Mock -CommandName Get-NetRoute -MockWith { 
                    @{
                        InterfaceAlias    = "Ethernet2"
                        DestinationPrefix = $testRoute.destination
                        NextHop           = $testRoute.gateway
                        RouteMetric       = $testRoute.metric
                    } }

                { $script:result = Invoke-AnsibleModule -params $testRouteNew } | Should -Not -Throw
                $script:result.changed | Should -Be $true
                $script:result.output | Should -Be 'Route updated'
                $script:result.state | Should -Be 'Present'
                $script:result.interface_alias | Should -Be $testRouteNew.interface_alias
                $script:result.destination | Should -Be $testRouteNew.destination
                $script:result.gateway | Should -Be $testRouteNew.gateway
                $script:result.metric | Should -Be $testRouteNew.metric                
            }

            It 'metric should be updated' {

                Mock -CommandName Get-NetRoute -MockWith { 
                    @{
                        InterfaceAlias    = $testRoute.interface_alias
                        DestinationPrefix = $testRoute.destination
                        NextHop           = $testRoute.gateway
                        RouteMetric       = 9
                    } }

                { $script:result = Invoke-AnsibleModule -params $testRouteNew } | Should -Not -Throw
                $script:result.changed | Should -Be $true
                $script:result.output | Should -Be 'Route updated'
                $script:result.state | Should -Be 'Present'
                $script:result.interface_alias | Should -Be $testRouteNew.interface_alias
                $script:result.destination | Should -Be $testRouteNew.destination
                $script:result.gateway | Should -Be $testRouteNew.gateway
                $script:result.metric | Should -Be $testRouteNew.metric                
            }

            It 'gateway should be updated' {

                Mock -CommandName Get-NetRoute -MockWith { 
                    @{
                        InterfaceAlias    = $testRoute.interface_alias
                        DestinationPrefix = $testRoute.destination
                        NextHop           = "0.0.0.0"
                        RouteMetric       = $testRoute.metric
                    } }

                { $script:result = Invoke-AnsibleModule -params $testRouteNew } | Should -Not -Throw
                $script:result.changed | Should -Be $true
                $script:result.output | Should -Be 'Route updated'
                $script:result.state | Should -Be 'Present'
                $script:result.interface_alias | Should -Be $testRouteNew.interface_alias
                $script:result.destination | Should -Be $testRouteNew.destination
                $script:result.gateway | Should -Be $testRouteNew.gateway
                $script:result.metric | Should -Be $testRouteNew.metric                
            }

        }
    }

}
finally {
    Invoke-TestCleanup
}

