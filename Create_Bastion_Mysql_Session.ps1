<#
This example demonstrates how to connect securely to a MySQL DB System endpoint using
a bastion and a connection
#>

param($BastionId, $ConnectionId)

$UserErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop" 
try {
    
    if ($null -eq $BastionId) {
        Throw "BastionId must be provided"
    }
    if ($null -eq $ConnectionId) {
        Throw "ConnectionId must be provided"
    }

    $Connection = Get-OCIDatabasetoolsConnection -DatabaseToolsConnectionId $ConnectionId

    $MysqlDbSystem = Get-OCIMysqlDbSystem -DbSystemId $Connection.RelatedResource.Identifier
    $Secret = Get-OCISecretsSecretBundle -SecretId $Connection.UserPassword.SecretId
 
    # Assign to local variables for readability
    $UserName = $Connection.UserName
    $PasswordBase64 = (Get-OCISecretsSecretBundle -SecretId $Secret.SecretId).SecretBundleContent.Content
    $TargetHost = $MysqlDbSystem.IpAddress
    $Port = $MysqlDbSystem.Port
    # Range 3307 to 3399
    $LocalPort = Get-Random -Minimum 3307 -Maximum 3399
 
    # Generate ephemeral key pair in ./tmp dir.  Send "y" just in case we generate a name for a file that has not been deleted 
    $KeyFile = -join("$PSScriptRoot/tmp/key-",(Get-Random))
    Out-Host -InputObject "y" | ssh-keygen -t rsa -b 2048 -f $KeyFile -q -N '' 

    # Move into dir and execute there ...
    Push-Location
    cd $PSScriptRoot
    $BastionSession=.\Create_Bastion_Forwarding_Session.ps1 -BastionId $BastionId -TargetHost $TargetHost -PublicKeyFile (-join($KeyFile, ".pub")) -Port $Port
    Pop-Location

    # Create ssh command argument string with relevant parameters
    $SshArgs = $BastionSession.SshMetadata["command"]
    $SshArgs = $SshArgs.replace("ssh", "") 
    $SshArgs = $SshArgs.replace("<privateKey>", $KeyFile)
    $SshArgs = $sshArgs.replace("<localPort>", $LocalPort)

    Out-Host -InputObject "CONN : ssh $sshArgs"
    # TODO: change from Minimized to Hidden when kill works 
    $SshProcess = Start-Process -FilePath "ssh" -ArgumentList $SshArgs -WindowStyle Hidden -PassThru

    $Password = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($PasswordBase64))
    mysqlsh -u $UserName -h 127.0.0.1 --port=$LocalPort --password=$Password
}
finally {

    # To Maximize possible clean ups, continue on error 
    $ErrorActionPreference = "Continue"

    Stop-Process -InputObject $SshProcess
    del $KeyFile
    del (-join($KeyFile, ".pub"))
        
    # Done, restore settings
    $ErrorActionPreference = $UserErrorActionPreference
}
