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
OCID of connection containing the details about the database system. 

.PARAMETER TestOnly
Set to $true to perform setup and teardown, but skip the start of sqlcl.
Incurs a 30 second wait. 

.EXAMPLE 
## Successfully invoking script and connecting to DB via bastion
❯ .\Invoke_Sqlcl_Session.ps1 -BastionId $bastion_ocid -ConnectionId $conn_ocid
Getting details from connection
Creating ephemeral key pair
Creating Port Forwarding Session to 10.0.1.113:1521
Waiting for creation of bastion session to complete
Creating SSH tunnel
Launching SQLcl


SQLcl: Release 22.2 Production on Tue Feb 07 17:44:56 2023

Copyright (c) 1982, 2023, Oracle.  All rights reserved.

Last Successful login time: Ti Feb 07 2023 17:44:57 +01:00

Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.18.0.1.0

SQL>

## Invoking script without setting path to sqlcl (sql)
.\Invoke_Sqlcl_Session.ps1 -BastionId $bastion_ocid -ConnectionId $conn_ocid
Write-Error: sql not found
Write-Error: Error: sqlcl not properly installed

## Invoking script with -TestOnly $true
❯ .\Invoke_Sqlcl_Session.ps1 -BastionId $bastion_ocid -ConnectionId $conn_ocid -TestOnly $true
Getting details from connection
Creating ephemeral key pair
Creating Port Forwarding Session to 10.0.1.113:1521
Waiting for creation of bastion session to complete
Creating SSH tunnel
DEBUG: Waiting in 30 secs while you check stuff ...
True

## Invoking script and getting errors and you do not know why (tip: go off VPN)
❯ .\Invoke_Sqlcl_Session.ps1 -BastionId $bastion_ocid -ConnectionId $adb_conn_ocid
Getting details from connection
Creating ephemeral key pair
Creating Port Forwarding Session to 10.0.1.51:1521
Waiting for creation of bastion session to complete
Creating SSH tunnel
Launching SQLcl


SQLcl: Release 22.2 Production on Thu Feb 09 07:40:57 2023

Copyright (c) 1982, 2023, Oracle.  All rights reserved.

  USER          = admin
  URL           = jdbc:oracle:thin:@tcps://127.0.0.1:9066/hikomo1xnp7z6id_myadb_low.adb.oraclecloud.com?ssl_server_dn_match=off
  Error Message = IO Error: The Network Adapter could not establish the connection (CONNECTION_ID=sh9DeAMwS9alZ/4KpbQ2DQ==)
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

    ## Make sure sqlcl is within reach first
    if ($false -eq (Test-OpuSqlclAvailable)) {
        throw "sqlcl not properly installed"
    }

    ## Import the modules needed here
    Import-Module OCI.PSModules.Database
    Import-Module OCI.PSModules.Databasetools
    Import-Module OCI.PSModules.Secrets

    Out-Host -InputObject "Getting details from connection"

    ## Grab main handle, ensure it is in correct lifecycle state and that it points to an adb instance
    try {
        $connection = Get-OCIDatabasetoolsconnection -DatabaseToolsconnectionId $connectionId -WaitForLifecycleState Active -WaitIntervalSeconds 0 -ErrorAction Stop        
    }
    catch {
        throw "Get-OCIDatabasetoolsconnection: $_"
    }
    if ("Autonomousdatabase" -ne $connection.RelatedResource.EntityType) {
        throw "Connection does not point to an Autonomous database"
    }

    ## Grab adb info based on conn handle, ensure it is in correct lifecycle state
    try {
        $adb = Get-OCIDatabaseAutonomousDatabase -AutonomousDatabaseId $connection.RelatedResource.Identifier -WaitForLifecycleState Available -WaitIntervalSeconds 0 -ErrorAction Stop        
    }
    catch {
        throw "Get-OCIDatabaseAutonomousDatabase: $_"
    }

    ## Get secret (read password) from connection handle
    try {
        $secret = Get-OCISecretsSecretBundle -SecretId $connection.UserPassword.SecretId -Stage Current -ErrorAction Stop         
    }
    catch {
        throw "Get-OCISecretsSecretBundle: $_"
    }

    ## Create connection string
    $fullConnStr = $adb.ConnectionStrings.Low
    $connStr =  $fullConnStr.Substring($fullConnStr.LastIndexOf("/") + 1)

    ## Assign to local variables for readability
    $userName = $connection.UserName
    $passwordBase64 = $secret.SecretBundleContent.Content
    $targetHost = $adb.PrivateEndpointip
    $targetPort = 1521
  
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
  
    Out-Host -InputObject "Launching SQLcl"
    sql -L ${userName}/${password}@tcps://127.0.0.1:${localPort}/${connStr}?ssl_server_dn_match=off
}
catch {
    ## What else can we do?
    Write-Error "Error caught: $_"
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
