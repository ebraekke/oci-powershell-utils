<#
This example demonstrates how to connect securely to a MySQL DB System endpoint using
a bastion and a connection
#>

param($CompartmentId, $BastionId, $TargetHost, $PublicKeyFile, $Port=22)

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
        Throw "TargetHost ip must be provided"
    }
    if ($null -eq $PublicKeyFile) {
        Throw "PublicKeyFile must be provided"
    }
    
    Out-Host -InputObject "Creating Port Forwarding Session"
    Out-Host -InputObject "Using port: $Port"

    # Import the modules
    Import-Module OCI.PSModules.Bastion

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
    
    Out-Host -InputObject "Waiting for session creation of bastion to complete"
    $BastionSession = Get-OCIBastionSession -SessionId $BastionSession.Id -WaitForLifecycleState Active, Failed
    
    $BastionSession
}
finally {
    # To Maximize possible clean ups, continue on error 
    $ErrorActionPreference = "Continue"
        
    # Done, restore settings
    $ErrorActionPreference = $UserErrorActionPreference
}
