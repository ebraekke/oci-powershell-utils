<#
.SYNOPSIS
Invoke  an sqlcl sesssion with a target host accessible through the OCI Bastion service.

.DESCRIPTION
Using the Bastion service and tunneling a sqlcl session will be invoked on the target DB system. 
A ephemeral key pair for the Bastion session is created (and later destroyed). 
This combo will allow you to "connect" through the Bastion service via a local port and to your destination: $TargetHost:$TargetPort   
A path from the Bastion to the target is required.
The Bastion session inherits TTL from the Bastion (instance). 

.PARAMETER BastionId
OCID of Bastion with wich to create a session. 
 
.PARAMETER ConnectionId
OCID of connection containing the details about teh database system. 

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

<# Kinda flow

$conn_ocid = "ocid1.databasetoolsconnection.oc1.eu-frankfurt-1.amaaaaaa3gkdkiaandprptbrd3puenlpt75peoqexr6xnfnoncuq27monnca"

$my_conn = Get-OCIDatabasetoolsConnection -DatabaseToolsConnectionId $conn_ocid

$my_db = Get-OCIDatabaseAutonomousDatabase -AutonomousDatabaseId $my_conn.RelatedResource.Identifier


$target_ip = $my_db.PrivateEndpointip


$conn_str = $adb.ConnectionStrings.Low

$conn_str
adb.eu-frankfurt-1.oraclecloud.com:1522/hikomo1xnp7z6id_myadb_low.adb.oraclecloud.com

$conn_str.Substring($conn_str.LastIndexOf("/") + 1)
hikomo1xnp7z6id_myadb_low.adb.oraclecloud.com


.\sql <usr>/<pwd>@tcps://127.0.0.1:9068/hikomo1xnp7z6id_myadb_low.adb.oraclecloud.com?ssl_server_dn_match=off
#>

try {
    ## START: generic section
    ## check that mandatory sw is installed    
    if ($false -eq (Test-OpuSshAvailable)) {
        throw "SSH not properly installed"
    }
    ## END: generic section

    ## Make sure mysqlsh is within reach first
    if ($false -eq (Test-OpuSqlclAvailable)) {
        throw "sqlcl not properly installed"
    }

    ## Import the modules needed here
    Import-Module OCI.PSModules.Database
    Import-Module OCI.PSModules.Databasetools
    Import-Module OCI.PSModules.Secrets

    Out-Host -InputObject "Getting details from connection"
    ## Grab main handle
    $connection = Get-OCIDatabasetoolsconnection -DatabaseToolsconnectionId $connectionId

    ## Get adb, service_name and secret based on handle
    $adb = Get-OCIDatabaseAutonomousDatabase -AutonomousDatabaseId $connection.RelatedResource.Identifier
    $fullConnStr = $adb.ConnectionStrings.Low
    $connStr =  $fullConnStr.Substring($fullConnStr.LastIndexOf("/") + 1)
    $secret = Get-OCISecretsSecretBundle -SecretId $connection.UserPassword.SecretId
 
    ## Assign to local variables for readability
    $userName = $connection.UserName
    $passwordBase64 = (Get-OCISecretsSecretBundle -SecretId $Secret.SecretId).SecretBundleContent.Content
    $targetHost = $adb.PrivateEndpointip
    $targetPort = 1521
  
    ## START: generic section
    ## Create session and process, get information in custom object -- see below
    $bastionSessionDescription = New-OpuPortForwardingSessionFull -BastionId $BastionId -TargetHost $TargetHost -TargetPort $TargetPort
    $localPort = $bastionSessionDescription.LocalPort
    ## END: generic section
  
    $password = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($passwordBase64))

    if ($true -eq $TestOnly) {
        Out-Host -InputObject "DEBUG: Waiting in 120 secs while you check stuff ..."
        Start-Sleep -Seconds 120
        return $true
    }
  
    Out-Host -InputObject "Launching SQLcl"
    # TODO: Resolve parameter passing issue wrt special characters
    sql -L ${userName}/${password}@tcps://127.0.0.1:${localPort}/${connStr}?ssl_server_dn_match=off
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
