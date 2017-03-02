# PowerShell Sitecore Role Configurator
by Zachary Kniebel

### Overview 

PowerShell scripts for configuring a Sitecore 8+ instance for a particular role (e.g. CM, CD, Processing, Reporting, etc.), with the 
desired search provider(s). 

The scripts support configuration using Sitecore-provided "Config Enable/Disable Spreadsheet" (converted to CSV) as input and include a 
tool for testing/debugging the spreadsheet to find and fix any inconsistencies that would otherwise break the configuration script. 

The configuration script is meant seamlessly integrate with CI-build tools (e.g. TeamCity, Octopus, etc.), instance setup scripts, or from 
the command prompt or PowerShell shell. 

### Credit

The configuration script was written by Zachary Kniebel, using Michael West's original script as a foundation. Michael West's original
script may be found here: https://gist.github.com/michaellwest/d1124a459cb1fb47486f87d488ecfab8#file-sitecoreroleconfigurator-ps1
