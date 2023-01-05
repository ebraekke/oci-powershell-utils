<#
This example demonstrates how to connect securely to a MySQL DB System endpoint using
a bastion and a connection
#>

param($BastionId, $ConnectionId, $PublicKeyFile)

$UserErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop" 
try {
    
    if ($null -eq $BastionId) {
        Throw "BastionId must be provided"
    }
    if ($null -eq $ConnectionId) {
        Throw "ConnectionId must be provided"
    }
    if ($null -eq $PublicKeyFile) {
        Throw "PublicKeyFile must be provided"
    }

    $PrivateKeyFile = $PublicKeyFile.replace(".pub", ".ppk")
    if  ($false -eq (Test-Path $PrivateKeyFile)) {
        Throw "$PrivateKeyFile does not exist"
    }
    Out-Host -InputObject "Will be using private key file $PrivateKeyFile"

    $Connection = Get-OCIDatabasetoolsConnection -DatabaseToolsConnectionId $ConnectionId

    $MysqlDbSystem = Get-OCIMysqlDbSystem -DbSystemId $Connection.RelatedResource.Identifier
    $Secret = Get-OCISecretsSecretBundle -SecretId $Connection.UserPassword.SecretId
 
    # Assign to local vcariables for readability
    $UserName = $Connection.UserName
    $PasswordBase64 = (Get-OCISecretsSecretBundle -SecretId $Secret.SecretId).SecretBundleContent.Content
    $TargetHost = $MysqlDbSystem.IpAddress
    $Port = $MysqlDbSystem.Port
 
    # Move into dir and execute there ...
    Push-Location
    cd $PSScriptRoot
    $BastionSession=.\Create_Bastion_Forwarding_Session.ps1 -BastionId $BastionId -TargetHost $TargetHost -PublicKeyFile $PublicKeyFile -Port $Port
    Pop-Location

    # Create putty command string that will be accepted ...
    $Str = $BastionSession.SshMetadata["command"]
    $Str = $Str.replace("ssh", "putty")
    $Str = $Str.replace("<privateKey>", $PrivateKeyFile)
    $Str = $Str.replace("<localPort>", $Port)
    $Str = $Str.replace("-p", "-P")
    $Str = $Str.replace("~", "$HOME")
    $Str = $Str.replace("/", "\")

    Out-Host -InputObject "CONN : $Str"

    $BastionSession
}
finally {



    # To Maximize possible clean ups, continue on error 
    $ErrorActionPreference = "Continue"
        
    # Done, restore settings
    $ErrorActionPreference = $UserErrorActionPreference
}
