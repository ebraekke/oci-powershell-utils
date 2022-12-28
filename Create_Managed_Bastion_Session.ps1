<#
This example demonstrates how to create a managed ssh session to a known host identfied by a ocid 
#>

param($CompartmentId, $BastionId, $TargetHost, $PublicKeyFile, $Port, $IsSsHSession, $OsSystemUser)

$UserErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop" 
try {

    if ($null -eq $CompartmentId) {
        Throw "CompartmentId must be provided"
    }
    if ($null -eq $BastionId) {
        Throw "BastionId must be provided"
    }
    if ($null -eq $TargetHost) {
        Throw "TargetHost ocid  must be provided"
    }
    if ($null -eq $PublicKeyFile) {
        Throw "PublicKeyFile must be provided"
    }
    if ($null -eq $Port) {
        Out-Host -InputObject "Using port 22"
    }
    if (($null -eq $IsSsHSession) -or ([Bool]'True' -eq $IsSsHSession)) {
        $CreateManagedSshSession = [Bool]'True'
        Out-Host -InputObject "Creating managed SSH session"
    }

    $OsUser = if ($null -eq $OsSystemUser) { "opc" } else { $OsSystemUser }
    Out-Host -InputObject "User for session: $OsUser"

    # Import the modules
    Import-Module OCI.PSModules.Bastion

    # Get Bastion object, use MaxSessionTtlInSeconds
    $BastionService         = Get-OCIBastion -BastionId $BastionId
    $MaxSessionTtlInSeconds = $BastionService.MaxSessionTtlInSeconds

    # Managed Session
    $TargetResourceDetails                                        = New-Object -TypeName 'Oci.BastionService.Models.CreateManagedSshSessionTargetResourceDetails'
    $TargetResourceDetails.TargetResourceOperatingSystemUserName  = $OsUser
    $TargetResourceDetails.TargetResourceId                       = $TargetHost
    
    # Generic for both models
    $TargetResourceDetails.TargetResourcePort                         = if ($null -eq $Port) { 22 } else { $Port }

    # Details of keyfile
    $KeyDetails                  = New-Object -TypeName 'Oci.BastionService.Models.PublicKeyDetails'
    $K                           = Get-Content $PublicKeyFile
    $KeyDetails.PublicKeyContent = $K

    # The actual session
    $SessionDetails                       = New-Object -TypeName 'Oci.BastionService.Models.CreateSessionDetails'
    $SessionDetails.DisplayName           = -join("BastionSession-", (Get-Random))
    $SessionDetails.SessionTtlInSeconds   = $MaxSessionTtlInSeconds
    $SessionDetails.BastionId             = $BastionId
    $SessionDetails.KeyType               = "PUB"
    $SessionDetails.TargetResourceDetails = $TargetResourceDetails
    $SessionDetails.KeyDetails            = $KeyDetails

    # Last statement, object will be returned to calling session
    New-OciBastionSession -CreateSessionDetails $SessionDetails
}
finally {
    # To Maximize possible clean ups, continue on error 
    $ErrorActionPreference = "Continue"
        
    # Done, restore settings
    $ErrorActionPreference = $UserErrorActionPreference
}
