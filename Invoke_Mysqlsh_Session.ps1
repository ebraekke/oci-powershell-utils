<#
.SYNOPSIS
Invoke  an mysqlsh sesssion with a target host accessible through the OCI Bastion service.

.DESCRIPTION
Using the Bastion service and tunneling a mysqlsh session will be invoked on the target DB system. 
A ephemeral key pair for the Bastion session is created (and later destroyed). 
This combo will allow you to "connect" through the Bastion service via a local port and to your destination: $TargetHost:$TargetPort   
A path from the Bastion to the target is required.
The Bastion session inherits TTL from the Bastion (instance). 

.PARAMETER BastionId
OCID of Bastion with wich to create a session. 
 
.PARAMETER ConnectionId
OCID of connection containign the details about teh database system. 

.PARAMETER TestOnly
Set to $true to perform setup and teardown, but skip the start of msqlsh.
Incurs a 30 second wait. 

.EXAMPLE 

#>

param(
    [Parameter(Mandatory, HelpMessage='OCID of Bastion')]
    [String]$BastionId, 
    [Parameter(Mandatory, HelpMessage='OCID of connection')]
    [String]$ConnectionId,
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
    if ($false -eq (Test-OpuSshAvailable)) {
        throw "SSH not properly installed"
    }
    ## END: generic section
    
    ## Import the modules needed here
    Import-Module OCI.PSModules.Mysql
    Import-Module OCI.PSModules.Databasetools
    Import-Module OCI.PSModules.Secrets

    Out-Host -InputObject "Getting details from connection"
    ## Grab main handle
    $connection = Get-OCIDatabasetoolsconnection -DatabaseToolsconnectionId $connectionId

    ## Get db system and secret based on handle
    $mysqlDbSystem = Get-OCIMysqlDbSystem -DbSystemId $connection.RelatedResource.Identifier
    $secret = Get-OCISecretsSecretBundle -SecretId $connection.UserPassword.SecretId
 
    ## Assign to local variables for readability
    $userName = $connection.UserName
    $passwordBase64 = (Get-OCISecretsSecretBundle -SecretId $Secret.SecretId).SecretBundleContent.Content
    $targetHost = $mysqlDbSystem.IpAddress
    $targetPort = $mysqlDbSystem.Port
  
    ## START: generic section
    ## Create session and process, get information in custom object -- see below
    $bastionSessionDescription = New-OpuPortForwardingSessionFull -BastionId $BastionId -TargetHost $TargetHost -TargetPort $TargetPort
    $localPort = $bastionSessionDescription.LocalPort
    ## END: generic section
  
    $password = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($passwordBase64))

    if ($true -eq $TestOnly) {
        Out-Host -InputObject "DEBUG: Waiting in 30 secs while you check stuff ..."
        Start-Sleep -Seconds 30
        return $true
    }
    
    mysqlsh -u $userName -h 127.0.0.1 --port=$localPort --password=$password
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
    
    ## Request cleanup 
    Remove-OpuPortForwardingSessionFull -BastionSessionDescription $bastionSessionDescription

    ## Finally, unload meodule from memory 
    Set-Location $PSScriptRoot
    Remove-Module oci-powershell-utils
    Pop-Location

    ## Done, restore settings
    $ErrorActionPreference = $userErrorActionPreference
    ## END: generic section
}
