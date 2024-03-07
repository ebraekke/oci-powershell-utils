#!/usr/bin/env pwsh

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

.PARAMETER SecretId
OCID of secret holding the SSH key for this host. 

.PARAMETER TargetPort
Port number at TargetHost to create a session to. 
Defaults to 22.  

.PARAMETER OsUser
Os user to connect with at target. 
Defaults to opc. 

.EXAMPLE 
## Creating a SSH session to the default port with the default user
❯ .\Invoke_Ssh_Session.ps1 -BastionId $bastion_ocid -TargetHost 10.0.1.102 -SecretId $ssh_key_ocid
Getting the SSH key from the secrets vault
Creating ephemeral key pair
Creating Port Forwarding Session to 10.0.1.102:22
Waiting for creation of bastion session to complete
Creating SSH tunnel
Waiting until SSH tunnel is ready (10 seconds)
Validating downloaded key...

...

Last login: Sun Mar  5 16:29:54 2023 from 10.0.0.49
#>

param(
    [Parameter(Mandatory, HelpMessage='OCID of Bastion')]
    [String]$BastionId, 
    [Parameter(Mandatory,HelpMessage='IP address of target host')]   
    [String]$TargetHost,
    [Parameter(Mandatory, HelpMessage='OCIC of secret hold SSH key')]
    [String]$SecretId,
    [Parameter(HelpMessage='Port at Target host')]
    [Int32]$TargetPort=22,
    [Parameter(HelpMessage='User to connect at target (opc)')]
    [String]$OsUser="opc"
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
    
    Out-Host -InputObject "Getting the SSH key from the secrets vault"

    ## Get secret (read ssh key) from SecretId
    try {
        $secret = Get-OCISecretsSecretBundle -SecretId $SecretId -Stage Current -ErrorAction Stop
    }
    catch {
        throw "Get-OCISecretsSecretBundle: $_"
    }

    ## START: generic section
    ## Create session and process, get information in custom object -- see below
    $bastionSessionDescription = New-OpuPortForwardingSessionFull -BastionId $BastionId -TargetHost $TargetHost -TargetPort $TargetPort
    $localPort = $bastionSessionDescription.LocalPort
    ## END: generic section
    
    ## Generate name for temp SSH key file, tmpDir + name of BastionSession
    $tmpDir = Get-TempDir
    $sshKey = -join("${tmpDir}/", $bastionSessionDescription.BastionSession.DisplayName) 

    ## Get Base64 encoded content and store in temp SSH key file  
    $sshKeyContent = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($secret.SecretBundleContent.Content))
    try {
        New-Item -Path $sshKey -Value $sshKeyContent -ErrorAction Stop | Out-Null
    }
    catch {
        throw "New-Item: $_"
    }

    ## Make sure to set as rw for owner 
    if ($IsLinux) {
        chmod 0600 $sshKey
    }

    Out-Host -InputObject "Validating downloaded SSH key"
    ssh-keygen -y -f ($sshKey.Replace("~", $HOME)) | Out-Null
    if ($false -eq $?) {
        throw "SecretId points to a invalid private SSH key"
    }

    ## NOTE 1: 'localhost' and not '127.0.0.1'
    ## Behaviour with both ssh and putty is unreliable when not using 'localhost'.
    ## NOTE2: -o 'NoHostAuthenticationForLocalhost yes' 
    ## Ensures no verification of locally forwarded port and localhost combos. 
    ssh -4 -o 'NoHostAuthenticationForLocalhost yes' -p $localPort localhost -l $OsUser -i $sshKey
}
catch {
    ## What else can we do? 
    Write-Error "Invoke_Ssh_Session.ps1: $_"
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

    ## Delete temp SSH key file
    $ErrorActionPreference = 'SilentlyContinue' 
    Remove-Item $SshKey -ErrorAction SilentlyContinue
    $ErrorActionPreference = "Continue"

    ## Finally, unload meodule from memory 
    Set-Location $PSScriptRoot
    Remove-Module oci-powershell-utils
    Pop-Location

    ## Done, restore settings
    $ErrorActionPreference = $userErrorActionPreference
    ## END: generic section
}
