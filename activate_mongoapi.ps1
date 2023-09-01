

$adb_ocid = "ocid1.autonomousdatabase.oc1.eu-frankfurt-1.antheljt3gkdkiaafrau4nwxij4kxmbkxazn4olsfbhab4ztkb4de6f7d7cq"

$adb = Get-OCIDatabaseAutonomousDatabase -AutonomousDatabaseId $adb_ocid -WaitForLifecycleState Available -WaitIntervalSeconds 0 -ErrorAction Stop

if (0 -eq ($adb.DbToolsDetails | Where-Object {$_.IsEnabled -eq 'True'} | Where-Object {$_.Name -eq 'MongodbApi'}).Count) {
	throw "MongodbApi is not enabled"
}


# Not Mongo
$adb.DbToolsDetails | Where-Object {$_.Name -ne 'MongodbApi'}
<<
           Name IsEnabled ComputeCount MaxIdleTimeInMinutes
           ---- --------- ------------ --------------------
           Apex      True
 DataTransforms      True
DatabaseActions      True
    GraphStudio      True
            Oml      True
           Ords      True


$adb.DbToolsDetails | Where-Object {$_.Name -eq 'MongodbApi'}
<<
      Name IsEnabled ComputeCount MaxIdleTimeInMinutes
      ---- --------- ------------ --------------------
MongodbApi     False


$adbUpdateDetails = New-Object -TypeName 'Oci.DatabaseService.Models.UpdateAutonomousDatabaseDetails'

$dbToolsDetails = New-Object -TypeName 'Oci.DatabaseService.Models.DatabaseTool'

Name IsEnabled ComputeCount MaxIdleTimeInMinutes
---- --------- ------------ --------------------


$dbToolsDetails[0].IsEnabled = $true
$dbToolsDetails[0].Name = "MongodbApi"

Update-OCIDatabaseAutonomousDatabase


Oci.DatabaseService.Models.UpdateAutonomousDatabaseDetails


Update-OCIDatabaseAutonomousDatabase -AutonomousDatabaseId $adb_ocid -UpdateAutonomousDatabaseDetails $adbUpdateDetails
