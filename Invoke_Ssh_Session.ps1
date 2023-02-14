<#
.SYNOPSIS
Invoke  an SSH  sesssion with a target host accessible through the OCI Bastion service.

.DESCRIPTION
Using the Bastion service and tunneling a SSH session will be invoked on the target host. 
A ephemeral key pair for the Bastion session is created (and later destroyed). 
Since the script relies on port forwarding, the bastion agent is not a requirment on the target.  
This combo will allow you to "ssh" through the Bastion service via a local port and to your destination: $TargetHost:$TargetPort   
A path from the Bastion to the target is required.
The Bastion session inherits TTL from the Bastion (instance). 


.PARAMETER BastionId
OCID of Bastion with wich to create a session. 
 
.PARAMETER TargetHost
IP address of target host. 
   
.PARAMETER TargetPort
Port number at TargetHost to create a session to. 
Defaults to 22.  

.PARAMETER OsUser
Os user to connect with at target. 
Defaults to opc. 

.PARAMETER TestOnly
Set to $true to perform setup and teardown, but skip the start of msqlsh.
Incurs a 30 second wait. 

.EXAMPLE 
## Creating a SSH session to the default port with a non-default user (not 10.0.0.49 i BAstion service private ip)
.\Invoke_Ssh_Session.ps1 -BastionId $bastion_ocid -TargetHost $target_ip -SshKey ~/.ssh/id_rsa -OsUser ubuntu
Creating Port Forwarding Session to 10.0.0.251:22
Waiting for creation of bastion session to complete
...
Last login: Tue Jan 17 15:11:50 2023 from 10.0.0.49
#>

param(
    [Parameter(Mandatory, HelpMessage='OCID of Bastion')]
    [String]$BastionId, 
    [Parameter(Mandatory,HelpMessage='IP address of target host')]   
    [String]$TargetHost,
    [Parameter(Mandatory, HelpMessage='SSH Key file for auth')]
    [String]$SshKey,
    [Parameter(HelpMessage='Port at Target host')]
    [Int32]$TargetPort=22,
    [Parameter(HelpMessage='User to connect at target (opc)')]
    [String]$OsUser="opc",
    [Boolean]$TestOnly=$false
)

## START: generic section
$UserErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop" 

Set-Location $PSScriptRoot
Import-Module './oci-powershell-utils.psm1'
Pop-Location
## END: generic section

try {
    ## START: generic section
    ## check that mandatory sw is installed    
    Test-OpuSshAvailable
    ## END: generic section
    
    if ($IsMacOS) {
        throw "Invoke_Ssh_session.ps1: Platform not supported!"
    }

    ## Make sure mandatory input at least is a proper file  
    if ($false -eq (Test-Path $SshKey -PathType Leaf)) {
        throw "${SshKey} is not a valid file"        
    }
    
    ## use ssh-keygen to print public part of key
    ## ssh-keygen on Windows does not like "~", so convert to "$HOME"
    Out-Host -InputObject "Validating key, provide password if prompted"
    ssh-keygen -y -f ($sshKey.Replace("~", $HOME)) | Out-Null
    if ($false -eq $?) {
        throw "$SshKey is not a valid private ssh key"
    }

    ## START: generic section
    ## Create session and process, get information in custom object -- see below
    $bastionSessionDescription = New-OpuPortForwardingSessionFull -BastionId $BastionId -TargetHost $TargetHost -TargetPort $TargetPort
    $localPort = $bastionSessionDescription.LocalPort
    ## END: generic section
    
    if ($true -eq $TestOnly) {
        Out-Host -InputObject "DEBUG: Waiting in 30 secs while you check stuff ..."
        Start-Sleep -Seconds 30
        return $true
    }

    ## NOTE 1: 'localhost' and not '127.0.0.1'
    ## Behaviour with both ssh and putty is unreliable when not using 'localhost'.
    ## NOTE2: -o 'NoHostAuthenticationForLocalhost yes' 
    ## Ensures no verification of locally forwarded port and localhost combos. 
    ssh -4 -o 'NoHostAuthenticationForLocalhost yes' -p $localPort localhost -l $OsUser -i $SshKey
}
catch {
    ## What else can we do? 
    Write-Error "Error: $_"
    return $false
}
finally {
    ## START: generic section
    ## To Maximize possible clean ups, continue on error 
    $ErrorActionPreference = "Continue"
    
    ## Request cleanup if session object has been created
    if ($null -ne $bastionSessionDescription) {
        Remove-OpuPortForwardingSessionFull -BastionSessionDescription $bastionSessionDescription
    }

    ## Finally, unload meodule from memory 
    Set-Location $PSScriptRoot
    Remove-Module oci-powershell-utils
    Pop-Location

    ## Done, restore settings
    $ErrorActionPreference = $userErrorActionPreference
    ## END: generic section
}
