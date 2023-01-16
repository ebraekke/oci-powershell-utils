# How to 

Import-Module .\oci-powershell-utils.psm1
Remove-Module oci-powershell-utils

Get-Help cmdlet

# ebraekke/oci-powershell-utils

PowerShell scripts that utilize the the PowerShell API for OCI.

The goal is to highlight the possibilities inherent in the robust feature set of OCI. 
Specifically: Bastion Service and Database Tools.  

## Content 

Two utility scripts that also can be used stand-alone: 

* Create_Bastion_Managed_SSH_Session.ps1
* Create_Bastion_SSH_Port_Forwarding_Session.ps1

Database connectivity through Bastion: 

* Create_Mysqlsh_Session.ps1

## Requirements 


## Windows only? 

PowerShell is cross-platform, so it should work.  
But, I have not tried. 


# Future enhancement - return customs object that wraps session, include private and public key 

```
$FullBastion = [PSCustomObject]@{
    Session = $bastion_session
    PrivateKey = "hemmelig"
    PublicKey = "mindre hemmelig"
}
```

Keys will be pointers to (read names of) files. 

# Errors on quota? No forgot to delete session! 


```
Creating Port Forwarding Session
Using port: 22
Stop-Process: Cannot bind argument to parameter 'InputObject' because it is null.
New-OpuSshSessionByKey: Error: Error: Error returned by Bastion Service. Http Status Code: 400. ServiceCode: QuotaExceeded. OpcRequestId: /33DCA13100CDF4DB74EA2FF6EEBDF121/ED9C2CB4373F5B8DF5B584C1FD73673C. Message: You have already reached max quota for number of sessions that can be created on this bastion.
Operation Name: CreateSession
TimeStamp: 2023-01-16T11:49:43.974Z
Client Version: Oracle-DotNetSDK/51.0.0 (Win32NT/10.0.19044.0; .NET 7.0.0)  Oracle-PowerShell/47.0.0
Request Endpoint: POST https://bastion.eu-frankfurt-1.oci.oraclecloud.com/20210331/sessions
For details on this operation's requirements, see https://docs.oracle.com/iaas/api/#/en/bastion/20210331/Session/CreateSession.
Get more information on a failing request by using the -Verbose or -Debug flags. See https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/powershellconcepts.htm#powershellconcepts_topic_logging
For more information about resolving this error, see https://docs.oracle.com/en-us/iaas/Content/API/References/apierrors.htm#apierrors_400__400_quotaexceeded
If you are unable to resolve this Bastion issue, please contact Oracle support and provide them this full error message.
```

