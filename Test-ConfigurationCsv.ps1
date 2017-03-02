<#

  .SYNOPSIS 
  Executes the 'Invoke-SitecoreRoleConfigurator' script in "DryRun" mode, in order to analyze and repair
  any issues/bugs in the Excel file that Sitecore originally provided that would prevent the script from
  running during a build

 #>

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$False)] [string] $CsvSettingsFilePath = ".\ConfigurationCsv.Settings.xml",
  [Parameter(Mandatory=$False)] [string] $ConfiguratorScriptFilePath = ".\Invoke-SitecoreRoleConfigurator.ps1"
)

# stop execution on all errors
$ErrorActionPreference = "Stop";
$VerbosePreference = "Silentlycontinue"

Write-Host "`r`nCONFIGURATION CSV TESTING TOOL`r`n`r`n"

Write-Host "To use this tool, ensure that you have configured the relevant settings in the `"$CsvSettingsFilePath`" file. The test will run once for each of the Roles that are added in the settings file. If any errors are encountered, resolve them in the CSV file and re-run the tool.`r`n" 
Write-Host "Note that the most common error occurs when a 'Config Type' and 'Config File Name' in the CSV does not match up for a particular file (i.e. the file is of type 'disabled' but its name ends in '.config' or '.example'). For these issues, find the referenced file in the unmodified Sitecore source and update the CSV according to what you find.`r`n"
Write-Host "This tool runs in DryRun mode, only. No actual file-system operations will be performed`r`n`r`n"

Read-Host "Press [ENTER] to execute the tool"

# get the xml
[xml]$settings = Get-Content -Path $CsvSettingsFilePath

Write-Host "Executing tests..."

if (-not (Test-Path -Path $ConfiguratorScriptFilePath -PathType Leaf)) {
  throw [System.IO.FileNotFoundException] "File '$ConfiguratorScriptFilePath' specified for parameter 'ConfiguratorScriptFilePath' was not found. This file is required and should be the file containing the Invoke-SitecoreRoleConfigurator commandlet."
}

# dot-source the script containing the Invoke-SitecoreRoleConfigurator commandlet so that we can call it
. $ConfiguratorScriptFilePath

# run the test for each role defined in the settings, 
foreach ($role in $settings.Parameters.RoleColumnHeaders.RoleColumnHeader)  {
  # invoke with the DryRun flag to ensure that no changes are actually made; ApplicationFolderPath can be fake since we are running in DryRun mode (no changes will actually be made)
  Invoke-SitecoreRoleConfigurator -ApplicationFolderPath "C:\fake" -RoleColumn "$role" -CsvSettingsFilePath "$CsvSettingsFilePath" -DryRun 
}

# script will stop execution on all errors, so if we get here then no errors were encountered
Write-Host "`r`nTEST COMPLETED SUCCESSFULLY!`r`n"