<#
    .SYNOPSIS
        The following script prompts the user for a Sitecore server role, then applies the appropriate 
        configurations as specified by the spreadsheet.
        
    .NOTES
        Script was modified from its original version. Changes made are intended to support use by CI build
        servers - specifically TeamCity -, reduce the number of required manual changes to the original 
        Config Enable/Disable file provided by Sitecore, and to support selecting one or more search 
        providers that the instance should be configured for.

        Original version by Michael West
        2016-06-17
        https://gist.github.com/michaellwest/d1124a459cb1fb47486f87d488ecfab8#file-sitecoreroleconfigurator-ps1
#>

function Invoke-SitecoreRoleConfigurator {
    Param(
        [Parameter(Mandatory=$True)] [string] $ApplicationFolderPath,
        [Parameter(Mandatory=$True)] [string] $RoleColumn,
        [Parameter(Mandatory=$False)] [string] $CsvSettingsFilePath = ".\ConfigurationCsv.Settings.xml",
        [Parameter(Mandatory=$False)] [string[]] $ExcludedSearchProviders = @(),
        [Parameter(Mandatory=$False)] [string] $CsvFilePath,
        [Parameter(Mandatory=$False)] [string] $FileNameColumn,
        [Parameter(Mandatory=$False)] [string] $FilePathColumn,
        [Parameter(Mandatory=$False)] [string] $DefaultExtensionColumn,
        [Parameter(Mandatory=$False)] [string] $SearchProviderColumn,
        [Parameter(Mandatory=$False)] [switch] $DryRun
    )
    $ErrorActionPreference = "Stop";
    $VerbosePreference = "Silentlycontinue"

    try {
        # make sure that the settings file exists
        if (-not (Test-Path -Path $CsvSettingsFilePath -PathType Leaf)) {
            throw [System.IO.FileNotFoundException] "Settings file '$CsvSettingsFilePath' suppied for parameter 'CsvSettingsFilePath' was not found. Settings file is required for script execution."
        }

        # get the xml
        [xml]$settings = Get-Content -Path $CsvSettingsFilePath
        
        # returns the value, if not null, or else the default value
        function Get-ValueOrDefault {
            Param([string] $Value, [string] $Default)
            if (!$Value) { return $Default } else { return $Value }
        }
        
        # apply default values from the XML settings, where needed
        $CsvFilePath = Get-ValueOrDefault $CsvFilePath $settings.Parameters.CsvFilePath;
        $FileNameColumn = Get-ValueOrDefault $FileNameColumn $settings.Parameters.FileNameColumnHeader
        $FilePathColumn = Get-ValueOrDefault $FilePathColumn $settings.Parameters.FilePathColumnHeader
        $DefaultExtensionColumn = Get-ValueOrDefault $DefaultExtensionColumn $settings.Parameters.DefaultExtensionColumnHeader
        $SearchProviderColumn = Get-ValueOrDefault $SearchProviderColumn $settings.Parameters.SearchProviderColumnHeader

        # trim values in excluded search providers
        $ExcludedSearchProviders = $ExcludedSearchProviders | ForEach-Object { $_.Trim() }

        # performs enabling/disabling of file by changing extension
        function Rename-ConfigFile {
            Param(
                [Parameter(Mandatory=$True)] [string] $ExistingName,
                [Parameter(Mandatory=$True)] [string] $TargetName,
                [Parameter(Mandatory=$False)] [string] $ContainerPath
            )

            # if a container path was supplied then join the path to the file names
            if ($ContainerPath) {
                $ExistingName = Join-Path -Path $ContainerPath -ChildPath $ExistingName
                $TargetName = Join-Path -Path $ContainerPath -ChildPath $TargetName
            }

            if(-not (Test-Path -Path $ExistingName)) {
                Write-Host "Skipping $ExistingName because the path does not exist."
                continue
            }

            # don't apply changes if this is DryRun mode
            if (-not $DryRun) {
                Move-Item -Path $ExistingName -Destination $TargetName
            }
        }

        # disables the file by changing the extension
        function Rename-DisableConfigFile {
            Param(
                [Parameter(Mandatory=$True)] [string] $ExistingName,
                [Parameter(Mandatory=$True)] [string] $ContainerPath
            )

            # change the extension the file
            $targetName = $fileName + ".disabled";

            # perform the renaming
            Rename-ConfigFile -ExistingName $ExistingName -TargetName $targetName -ContainerPath $ContainerPath
            Write-Host "`tFile successfully renamed to: $targetName"
        }

        # enables the file by changing the extension
        function Rename-EnableConfigFile {
            Param(
                [Parameter(Mandatory=$True)] [string] $ExistingName,
                [Parameter(Mandatory=$True)] [string] $DefaultExtension,
                [Parameter(Mandatory=$True)] [string] $ContainerPath
            )

            # remove the default extension
            $targetName = $ExistingName.Substring(0, $ExistingName.Length - $DefaultExtension.Length);
            
            # don't add '.config' if it's already there, e.g. if the file was originally 'Foo.config.disabled'
            if (!$targetName.EndsWith(".config")) {
                $targetName += ".config"
            }

            Rename-ConfigFile -ExistingName $ExistingName -TargetName $targetName -ContainerPath $ContainerPath
        }

        # import and parse the CSV
        $csvTable = Import-Csv -Path $CsvFilePath

        # loop through each row and enable/disable the file based on the given settings
        foreach($csvTableRow in $csvTable) {
            # get the full path to the config file's parent directory
            $configPath = Join-Path -Path $ApplicationFolderPath -ChildPath $csvTableRow.$FilePathColumn.Trim()
            $fileName = $csvTableRow.$FileNameColumn.Trim()
            $defaultExtension = ".$($csvTableRow.$DefaultExtensionColumn)".Trim()

            # enable, disable or skip based on the given role
            switch($csvTableRow.$RoleColumn.Trim()) {
                "Enable" {
                    Write-Host "Enable: $fileName"  

                    # before we enable the config, make sure that it is not for an excluded search provider
                    if ($ExcludedSearchProviders -contains $csvTableRow.$SearchProviderColumn.Trim()) {
                        if ($defaultExtension -eq ".config") {
                            Write-Host "`tDisabling file '$fileName'. File is for an excluded search provider." 
                            # disable the file
                            Rename-DisableConfigFile -ExistingName $fileName -ContainerPath $configPath
                        }
                        Write-Host "`tSkipping file '$fileName'. File is for an excluded search provider."
                    } else {
                        # there is an issue with the CSV - we could probably work around it, but better to have someone look at it
                        if (!$fileName.EndsWith($defaultExtension)) {
                            throw [System.Exception] "File '$fileName' does not have the expected extension '$defaultExtension'."
                        # file must have default extension - if it's not yet enabled then enable it
                        } elseif ($defaultExtension -ne ".config") {
                            Write-Host "`tRenaming $fileName to enable it"
                            Rename-EnableConfigFile -ExistingName $fileName -DefaultExtension $defaultExtension -ContainerPath $configPath
                        } else {
                            Write-Host "`tSkipping '$fileName' as it is already enabled"
                        }
                    }
                }
                "Disable" {
                    Write-Host "Disable: $fileName"

                    # there is an issue with the CSV - we could probably work around it, but better to have someone look at it
                    if (!$fileName.EndsWith($defaultExtension)) {
                        throw [System.Exception] "File '$fileName' does not have the expected extension '$defaultExtension'."
                    # if the file is enabled then disable it (we don't care about 'example' files, since they're already disabled)
                    } elseif ($defaultExtension -eq ".config") {
                        Write-Host "`tRenaming $fileName to disable it"
                        # disable the file
                        Rename-DisableConfigFile -ExistingName $fileName -ContainerPath $configPath
                    } else {                        
                        Write-Host "`tSkipping '$fileName' as it is already disabled"
                    }
                }
                default {
                }
            }
        }
    } catch {
        Write-Host "ERROR: An error was encountered and script execution was terminated. Details below:"

        $ErrorMessage = $_.Exception | Format-List -force
        Write-Output $ErrorMessage
        
        # if we are running in DryRun mode then we don't want to close the window
        if (-not $DryRun) {
            exit(1)
        }
    }
}