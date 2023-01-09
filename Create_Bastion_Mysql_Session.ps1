<#
This example demonstrates how to connect securely to a MySQL DB System endpoint using
a bastion session and a connection
#>

param($BastionId, $ConnectionId)

$UserErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop" 
try {
    
    function Verify-Mysqlsh {
        try {
            # run process 
            Start-Process -FilePath "mysqlsh" -ArgumentList "--help" -WindowStyle Hidden 
        }
        catch {
            throw "mysqlsh executable not found"
        }
    }

    function Verify-SshSuite {
        try {
            # run process 
            Start-Process -FilePath "ssh" -ArgumentList "--help" -WindowStyle Hidden 
        }
        catch {
            throw "ssh executable not found"
        }
        try {
            # run process 
            Start-Process -FilePath "ssh-keygen" -ArgumentList "--help" -WindowStyle Hidden 
        }
        catch {
            throw "ssh-keygen executable not found"
        }
    }

    function Verify-TmpDir {
        try {
            Test-Path $PSScriptRoot/tmp | Out-Null
        }
        catch {
            throw "Required directory $PSScriptRoot/tmp does not exist"
        }    
    }

    Verify-Mysqlsh
    Verify-SshSuite
    Verify-TmpDir

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
 
    # Generate ephemeral key pair in ./tmp dir.  
    # name: bastionkey-yyyy_dd_MM_HH_mm_ss-$LocalPort
    #
    # Process will fail if another key with same name exists, in that case -- do not delete key file(s) on exit
    $DeleteKeyOnExit = $false
    $KeyFile = -join("$PSScriptRoot/tmp/bastionkey-",(Get-Date -Format "yyyy_MM_dd_HH_mm_ss"),"-$LocalPort")
    ssh-keygen -t rsa -b 2048 -f $KeyFile -q -N '' 
    $DeleteKeyOnExit = $true

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

    # for debug, comment out for now
    # Out-Host -InputObject "CONN : ssh $sshArgs"
    $SshProcess = Start-Process -FilePath "ssh" -ArgumentList $SshArgs -WindowStyle Hidden -PassThru

    $Password = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($PasswordBase64))
    mysqlsh -u $UserName -h 127.0.0.1 --port=$LocalPort --password=$Password
}
finally {

    # To Maximize possible clean ups, continue on error 
    $ErrorActionPreference = "Continue"

    # Kill SSH process
    Stop-Process -InputObject $SshProcess

    # Delete ephemeral key pair if all went well
    if ($true -eq $DeleteKeyOnExit) {
        del $KeyFile
        del (-join($KeyFile, ".pub"))    
    } 
    
    # Kill Bastion session, with Force, ignore output (it is the work request id)
    Remove-OCIBastionSession -SessionId $BastionSession.id -Force | Out-Null

    # Done, restore settings
    $ErrorActionPreference = $UserErrorActionPreference
}
