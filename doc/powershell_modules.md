## What is installed 


```
Get-Module -ListAvailable
<<
---------- -------    ---------- ----                                --------- ----------------
Binary     71.0.0                OCI.PSModules.Common                Core      {Get-OCICmdletHistory, Set-OCICmdletHistory, Clear-O…
Binary     71.0.0                OCI.PSModules.Computeinstanceagent  Core      {Get-OCIComputeinstanceagentInstanceagentAvailablePl…
Binary     71.0.0                OCI.PSModules.Core                  Core      {Add-OCIComputeImageShapeCompatibilityEntry, Add-OCI…
Binary     71.0.0                OCI.PSModules.Database              Core      {Add-OCIDatabaseStorageCapacityCloudExadataInfrastru…
Binary     71.0.0                OCI.PSModules.Databasetools         Core      {Add-OCIDatabasetoolsConnectionLock, Add-OCIDatabase…
Binary     71.0.0                OCI.PSModules.Identity              Core      {Add-OCIIdentityTagDefaultLock, Add-OCIIdentityTagNa…
Binary     71.0.0                OCI.PSModules.Mysql                 Core      {Add-OCIMysqlHeatWaveCluster, Get-OCIMysqlBackup, Ge…
Binary     71.0.0                OCI.PSModules.Objectstorage         Core      {Copy-OCIObjectstorageObject, Get-OCIObjectstorageBu…
Binary     71.0.0                OCI.PSModules.Resourcemanager       Core      {Get-OCIResourcemanagerConfigurationSourceProvider, …
Binary     71.0.0                OCI.PSModules.Secrets               Core      {Get-OCISecretsSecretBundle, Get-OCISecretsSecretBun…
Binary     71.0.0                OCI.PSModules.Vault                 Core      {Get-OCIVaultSecret, Get-OCIVaultSecretsList, Get-OC…

...

```

## Install
```
Install-Module -Name OCI.PSModules.Common
Install-Module -Name OCI.PSModules.Core
Install-Module -Name OCI.PSModules.Bastion
Install-Module -Name OCI.PSModules.Computeinstanceagent
Install-Module -Name OCI.PSModules.Database
Install-Module -Name OCI.PSModules.DatabaseTools
Install-Module -Name OCI.PSModules.Identity
Install-Module -Name OCI.PSModules.Mysql
Install-Module -Name OCI.PSModules.Objectstorage
Install-Module -Name OCI.PSModules.Secrets
Install-Module -Name OCI.PSModules.Vault
Install-Module -Name OCI.PSModules.Resourcemanager
```





## Remove
```
Uninstall-Module -Name OCI.PSModules.Bastion
Uninstall-Module -Name OCI.PSModules.Computeinstanceagent
Uninstall-Module -Name OCI.PSModules.Database
Uninstall-Module -Name OCI.PSModules.DatabaseTools
Uninstall-Module -Name OCI.PSModules.Identity
Uninstall-Module -Name OCI.PSModules.Mysql
Uninstall-Module -Name OCI.PSModules.Objectstorage
Uninstall-Module -Name OCI.PSModules.Secrets
Uninstall-Module -Name OCI.PSModules.Vault
Uninstall-Module -Name OCI.PSModules.Resourcemanager
Uninstall-Module -Name OCI.PSModules.Core
Uninstall-Module -Name OCI.PSModules.Common
```


