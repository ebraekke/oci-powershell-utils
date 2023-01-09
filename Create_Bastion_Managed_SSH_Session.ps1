<#
This example demonstrates how to create a managed ssh session to a known host identfied by an ocid 
#>

param (
    [String]$BastionId, 
    [String]$TargetHostId,
    [String]$PublicKeyFile,
    [Int32]$Port=22,
    [String]$OsUser="opc"
)

$UserErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop" 

try {

    # Import the modules
    Import-Module OCI.PSModules.Bastion

    if ($null -eq $BastionId) {
        Throw "BastionId must be provided"
    }
    if ($null -eq $TargetHostId) {
        Throw "TargetHost ocid  must be provided"
    }
    if ($null -eq $PublicKeyFile) {
        Throw "PublicKeyFile must be provided"
    }
    
    Out-Host -InputObject "Using port $Port"
    Out-Host -InputObject "Creating managed SSH session"
    Out-Host -InputObject "User for session: $OsUser"

    # Get Bastion object, use MaxSessionTtlInSeconds
    $BastionService         = Get-OCIBastion -BastionId $BastionId
    $MaxSessionTtlInSeconds = $BastionService.MaxSessionTtlInSeconds

    # Managed Session
    $TargetResourceDetails                                        = New-Object -TypeName 'Oci.BastionService.Models.CreateManagedSshSessionTargetResourceDetails'
    $TargetResourceDetails.TargetResourceOperatingSystemUserName  = $OsUser
    $TargetResourceDetails.TargetResourceId                       = $TargetHostId
    
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
    $BastionSession = New-OciBastionSession -CreateSessionDetails $SessionDetails

    Out-Host -InputObject "Waiting for creation of bastion session to complete"
    $BastionSession = Get-OCIBastionSession -SessionId $BastionSession.Id -WaitForLifecycleState Active, Failed
    
    $BastionSession
}
finally {
    # To Maximize possible clean ups, continue on error 
    $ErrorActionPreference = "Continue"
        
    # Done, restore settings
    $ErrorActionPreference = $UserErrorActionPreference
}
