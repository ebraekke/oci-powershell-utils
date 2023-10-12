<#
.SYNOPSIS
Enable the MongoApi on a specific Autonomous Database (ADB).

.DESCRIPTION
. 

.PARAMETER AdbId
OCID of database where you want to enable MongoApi. 
 
.EXAMPLE 
## Succesfully invoking the script 

## Invoking the script with an invalid ADB ocid
❯ .\Enable_Mongoapi.ps1 -AdbId "xyz"
Write-Error: Enable_Mongoapi.ps1: Get-OCIDatabaseAutonomousDatabase: One or more errors occurred. (Authorization failed or requested resource not found.)

#>

param(
    [Parameter(Mandatory, HelpMessage='OCID of ADB')]
    [String]$AdbId 
)

## START: generic section
$UserErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop" 

Set-Location $PSScriptRoot
Import-Module './oci-powershell-utils.psm1'
Pop-Location
## END: generic section

try {

      ## Grab adb info based on conn handle to ensure it is in the correct lifecycle state
      try {
            $myAdb = Get-OCIDatabaseAutonomousDatabase -AutonomousDatabaseId $AdbId -WaitForLifecycleState Available -WaitIntervalSeconds 0 -ErrorAction Stop
      }
      catch {
            throw "Get-OCIDatabaseAutonomousDatabase: $_"
      }

      $adbUpdateDetails = New-Object -TypeName 'Oci.DatabaseService.Models.UpdateAutonomousDatabaseDetails'
      $dbToolsDetails = New-Object -TypeName 'Oci.DatabaseService.Models.DatabaseTool'

      $dbToolsDetails[0].IsEnabled = $true
      $dbToolsDetails[0].Name = "MongodbApi"

      $adbUpdateDetails.DbToolsDetails = $dbToolsDetails

      Update-OCIDatabaseAutonomousDatabase -AutonomousDatabaseId $AdbId -UpdateAutonomousDatabaseDetails $adbUpdateDetails -WaitForStatus Succeeded

} catch {
      ## What else can we do?
      Write-Error "Enable_Mongoapi.ps1: $_"
      return $false
  }
  finally {
      ## START: generic section
      ## To Maximize possible clean ups, continue on error 
      $ErrorActionPreference = "Continue"
        
      ## Finally, unload module from memory 
      Set-Location $PSScriptRoot
      Remove-Module oci-powershell-utils
      Pop-Location
  
      ## Done, restore settings
      $ErrorActionPreference = $userErrorActionPreference
      ## END: generic section
}
