<#
This example demonstrates how to create a port forwarding ssh session to a known host identfied by an ip-address
#>

param($CompartmentId, $BastionId, $TargetHost, $PublicKeyFile, $Port)

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
    if ($null -eq $Port) {
        Out-Host -InputObject "Using port 22"
    }

    Out-Host -InputObject "Creating Port Forwarding Session"

    # Import the modules
    Import-Module OCI.PSModules.Bastion

    # Get Bastion object, use MaxSessionTtlInSeconds
    $BastionService         = Get-OCIBastion -BastionId $BastionId
    $MaxSessionTtlInSeconds = $BastionService.MaxSessionTtlInSeconds

    # Details of target
    $TargetResourceDetails                                  = New-Object -TypeName 'Oci.BastionService.Models.CreatePortForwardingSessionTargetResourceDetails'
    $TargetResourceDetails.TargetResourcePrivateIpAddress   = $TargetHost    
    
    # Generic for both models
    $TargetResourceDetails.TargetResourcePort               = if ($null -eq $Port) { 22 } else { $Port }

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
