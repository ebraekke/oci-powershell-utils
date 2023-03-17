<#
.SYNOPSIS
Removes all traces of previously created "full session", that is Bastion session, SSH process and ephemeral key pair. 

.DESCRIPTION
The SSH process, the ephemeral key pair and then finally the bastion session are destroyed. 
Process will will continue if a failure happens.
File deletion failures are silent, you need to add debugging to get output.  
Output related to the bastion session deletion will be displayed. 

.PARAMETER BastionSessionDescription

$BastionSessionDescription = [PSCustomObject]@{
    BastionSession = $bastionSession
    SShProcess = $sshProcess
    PrivateKey = $keyFile
    PublicKey = "${keyFile}.pub"
    LocalPort = $localPort
}
 

.EXAMPLE 
## Removing previously created full session
Remove_Port_Forwarding_Session_Full.ps1 -BastionSessionDescription $full_session
True

.EXAMPLE 
## Attempting to remove a full session tha thas already been removed. 
Remove_Port_Forwarding_Session_Full.ps1 -BastionSessionDescription $full_session
Write-Error: Error: Error returned by Bastion Service. Http Status Code: 409. ServiceCode: Conflict. OpcRequestId: /6D37DAF3BE84C77C5795641630FEB81F/C8069151DFEDFD9499DD0BBDFC80E109. Message: resource is not allowed to delete with current state
Operation Name: DeleteSession
TimeStamp: 2023-01-25T17:28:17.979Z
Client Version: Oracle-DotNetSDK/51.0.0 (Win32NT/10.0.19044.0; .NET 7.0.0)  Oracle-PowerShell/47.0.0
Request Endpoint: DELETE https://bastion.eu-frankfurt-1.oci.oraclecloud.com/20210331/sessions/ocid1.bastionsession.oc1.eu-frankfurt-1.amaaaaaa3gkdkiaayyi4zkejketqvgs2bzlwirwdoqn5hmvhlsbryelkevxa
For details on this operation's requirements, see https://docs.oracle.com/iaas/api/#/en/bastion/20210331/Session/DeleteSession.
Get more information on a failing request by using the -Verbose or -Debug flags. See https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/powershellconcepts.htm#powershellconcepts_topic_logging
For more information about resolving this error, see https://docs.oracle.com/en-us/iaas/Content/API/References/apierrors.htm#apierrors_409__409_conflict
If you are unable to resolve this Bastion issue, please contact Oracle support and provide them this full error message. 
#>
param (
    [Parameter(Mandatory,HelpMessage='Full Bastion Session Description Object')]
    $BastionSessionDescription
)

$UserErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop" 

Set-Location $PSScriptRoot
Import-Module './oci-powershell-utils.psm1'
Pop-Location

try {
    ## Request cleanup, this will always "SUCCED", that is continue to tear down until all avenues have been explored  
    Remove-OpuPortForwardingSessionFull -BastionSessionDescription $BastionSessionDescription

}
catch {
    Write-Error "Remove_Port_Forwarding_Session_Full.ps1: $_"
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
