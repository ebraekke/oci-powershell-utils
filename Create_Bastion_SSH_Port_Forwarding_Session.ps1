<#
This example demonstrates how to create a port forwarding ssh session to a known host identfied by an ip-address
#>

param (
    [String]$BastionId, 
    [String]$TargetHost,
    [String]$PublicKeyFile,
    [Int32]$Port=22
)

$UserErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop" 

try {

    # Import the modules
    Import-Module OCI.PSModules.Bastion

    if ($null -eq $BastionId) {
        Throw "BastionId must be provided"
    }
    if ($null -eq $TargetHost) {
        Throw "TargetHost ip must be provided"
    }
    if ($null -eq $PublicKeyFile) {
        Throw "PublicKeyFile must be provided"
    } elseif ($false -eq (Test-Path $PublicKeyFile -PathType Leaf)) {
        Throw "$PublicKeyFile is not a valid file"        
    }
    
    Out-Host -InputObject "Creating Port Forwarding Session"
    Out-Host -InputObject "Using port: $Port"

    # Get Bastion object, use MaxSessionTtlInSeconds
    $BastionService         = Get-OCIBastion -BastionId $BastionId
    $MaxSessionTtlInSeconds = $BastionService.MaxSessionTtlInSeconds

    # Details of target
    $TargetResourceDetails                                  = New-Object -TypeName 'Oci.BastionService.Models.CreatePortForwardingSessionTargetResourceDetails'
    $TargetResourceDetails.TargetResourcePrivateIpAddress   = $TargetHost    
    
    # Generic for both models
    $TargetResourceDetails.TargetResourcePort               = $Port

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
