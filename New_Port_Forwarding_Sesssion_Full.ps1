<#
.SYNOPSIS
Create a port forwarding sesssion with OCI Bastion service.
Generate SSH key pair to be used for session.
Create the actual port forwarding SSH process.

Return an object to the caller:

$bastionSessionDescription = [PSCustomObject]@{
    BastionSession = $bastionSession
    SShProcess = $sshProcess
    PrivateKey = $keyFile
    PublicKey = "${keyFile}.pub"
    LocalPort = $localPort
}
        
.DESCRIPTION
Creates a port forwarding session with the OCI Bastion Service and the required SSH port forwarding process.
This combo will allow you to connect through the Bastion service via a local port and to your destination: $TargetHost:$TargetPort   
A path from the Bastion to the target is required.
The Bastion session inherits TTL from the Bastion (instance). 

.PARAMETER BastionId
OCID of Bastion with wich to create a session. 
 
.PARAMETER TargetHost
IP address of target host. 
   
.PARAMETER TargetPort
Port number at TargetHost to create a session to. 
Defaults to 22.  

.EXAMPLE 
## Creating a forwarding session to the default port
$bastion_session=New-Port_Forwarding_Session_Full -BastionId $bastion_ocid -TargetHost $target_ip
Creating Port Forwarding Session to 10.0.0.251:22
Waiting for creation of bastion session to complete

$bastion_session
BastionSession : Oci.BastionService.Models.Session
SShProcess     : System.Diagnostics.Process (Idle)
PrivateKey     : C:\Users\espenbr\AppData\Local\Temp/bastionkey-2023_01_17_14_43_21-9084
PublicKey      : C:\Users\espenbr\AppData\Local\Temp/bastionkey-2023_01_17_14_43_21-9084.pub
LocalPort      : 9084
#>
param(
    [Parameter(Mandatory, HelpMessage='OCID Bastion of Bastion')]
    [String]$BastionId, 
    [Parameter(Mandatory,HelpMessage='IP address of target host')]   
    [String]$TargetHost,
    [Parameter(HelpMessage='Port at Target host')]
    [Int32]$TargetPort=22,
    [Parameter(HelpMessage='Use this local port, 0 means assign')]
    [Int32]$LocalPort=0
)

$UserErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop" 

Set-Location $PSScriptRoot
Import-Module './oci-powershell-utils.psm1'
Pop-Location

try {
    ## check that mandatory sw is installed    
    if ($false -eq (Test-OpuSshAvailable)) {
        throw "SSH not properly installed"
    }
    
    ## Create session and process, get information in custom object -- return below
    $bastionSessionDescription = New-OpuPortForwardingSessionFull -BastionId $BastionId -TargetHost $TargetHost -TargetPort $TargetPort -LocalPort $LocalPort

    $bastionSessionDescription
}
catch {
    ## What else can we do? 
    Write-Error "Error: $_"
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
