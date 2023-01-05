# oci-powershell-utils

Powershell scripts that utilize the the PowerShell api for OCI 


# "Huskelapp" 

$PasswordDetails=New-Object -TypeName 'Oci.DatabasetoolsService.Models.DatabaseToolsUserPasswordDetails'

$MySqlDetails=New-Object -TypeName 'Oci.DatabasetoolsService.Models.CreateDatabaseToolsRelatedResourceMySqlDetails'

$MySqlDetails.EntityType="MYSQL"
$MySqlDetails.Identifier="ocid1.mysqldbsystem.oc1.eu-frankfurt-1.aaaaaaaasdkzjnwuaflsvhryxu7pw63igyhoj6xbmobi4wgkfnlumkpuwjyq"

$ConnectionMySqlDetails=New-Object -TypeName 'Oci.DatabasetoolsService.Models.CreateDatabaseToolsConnectionMySqlDetails'

$ConnectionMySqlDetails.RelatedResource=$MySqlDetails

RelatedResource    :
ConnectionString   :
UserName           :
UserPassword       :
AdvancedProperties :
KeyStores          :
PrivateEndpointId  :
DisplayName        :
CompartmentId      :
DefinedTags        ,:
FreeformTags       :