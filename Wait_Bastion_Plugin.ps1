<#
.SYNOPSIS
Waits for the Bastion plugin to be started by the OCI management agent. 

.DESCRIPTION
The process checks to see that the compute instance is in Lifecycle state "Running".
It then loops for 30 times 6 seconds, i.e. 180 seconds or 3 minutes in an attempt to 
query the status of the Bastion plugin under the *assumption* that
start of the plugin was requested at creation of the instance. 
This assumption is key, because querying the status of the agent shortly after 
startup of a node always throws an error. 

.PARAMETER CompartmentId
OCID of the compartment holding the compute instance.

.PARAMETER InstanceId
OCID of the compute instance to query.
 
.EXAMPLE 
## Query an instance where the Bastion plugin is already running
> .\Wait_Bastion_Plugin.ps1 -CompartmentId $C -InstanceId $started_instance
Bastion plugin is available.

.EXAMPLE 
## Query an intance where the Bastion plugin has been requested but is not yet activated
> .\Wait_Bastion_Plugin.ps1 -CompartmentId $C -InstanceId $starting_instance
Plugin is not available yet ...
Plugin is not available yet ...
Plugin is not available yet ...
Plugin is not available yet ...
Plugin is not available yet ...
Bastion plugin is available.

.EXAMPLE 
## Query an instance that has been terminated
> .\Wait_Bastion_Plugin.ps1 -CompartmentId $C -InstanceId $terminated_instance
Write-Error: Wait_Bastion_Plugin.ps1: Compute instance not "Running": One or more errors occurred. (Failed to reach desired state.)

.EXAMPLE 
## Query an instance that does not exist
> .\Wait_Bastion_Plugin.ps1 -CompartmentId $C -InstanceId $nonexisting_instance
Write-Error: Wait_Bastion_Plugin.ps1: Compute instance not "Running": One or more errors occurred. (Authorization failed or requested resource not found.)

#>
param (
    [Parameter(Mandatory,HelpMessage='OCID of compartment')]
    $CompartmentId,
    [Parameter(Mandatory,HelpMessage='OCID of instance (compute) node')]
    $InstanceId
)

$UserErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop" 

Set-Location $PSScriptRoot
Import-Module './oci-powershell-utils.psm1'
Pop-Location


try {

    ## Ensure instance is running
    try {
        Get-OCIComputeInstance -InstanceId $InstanceId -WaitForLifecycleState Running -WaitIntervalSeconds 0 | Out-Null  

    } catch {
        throw "Compute instance not `"Running`": $_"
    }

    $count = 0
    $notFound = $true
    while (($count++ -lt 31) -and $notFound) {
        try {
            $pluginStatus = Get-OCIComputeinstanceagentInstanceAgentPlugin -CompartmentId $CompartmentId -InstanceagentId $InstanceId -PluginName Bastion

            if ("Running" -eq $pluginStatus.Status) {
                Out-Host -InputObject "Bastion plugin is available."
                $notFound = $false
            } else {
                Out-Host "Agent responding, but status of Bastion plugin is not `"Running`""
            }
        } catch {
            Out-Host -InputObject "Plugin is not available yet ..."
        }     
        Start-Sleep -Seconds 6
    }
}
catch {
    Write-Error "Wait_Bastion_Plugin.ps1: $_"
    return $false
}
finally {
    ## To Maximize possible clean ups, continue on error 
    $ErrorActionPreference = "Continue"
    
    ## Finally, unload meodule from memory 
    Set-Location $PSScriptRoot
    Remove-Module oci-powershell-utils
    Pop-Location

    ## Done, restore settings
    $ErrorActionPreference = $userErrorActionPreference
}
