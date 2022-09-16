<#

DISCLAIMER
This code is distributed as-is, with no warranties attached.
Albeit functional, this code is not considered
production-quality and should not be deployed or
run against production instances unless reviewed,
modified and hardened by an expert party.
This code works as an example under an engagement between
StoneX Group and MongoDB Professional Services, and MongoDB
has no obligation to support it.

#>

# Parameter help description
param(
    [ValidateSet("backup", "restore")]
    [string]$action = "backup",
    [Parameter(Mandatory)][string]$fileName = "alerts.json",
    [string]$publicKey,
    [string]$privateKey,
    [string]$atlasProfile = "default",
    [string]$projectName,
    [string]$projectId
)

Import-Module -Name Microsoft.PowerShell.Utility

function Invoke-AtlasCommand([string]$command) {
    $fullCommand = "atlas " + $command + " --output json"
    if ($atlasProfile) {
        $fullCommand += " --profile " + $atlasProfile
    }
    if ($projectId) {
        $fullCommand += " --projectId " + $projectId
    }
    $fullCommand | Invoke-Expression | ConvertFrom-Json
}

function Invoke-SilentAtlasCommand([string]$command) {
    $fullCommand = "atlas " + $command
    if ($atlasProfile) {
        $fullCommand += " --profile " + $atlasProfile
    }
    if ($projectId) {
        $fullCommand += " --projectId " + $projectId
    }
    $fullCommand | Invoke-Expression
}

function FindProjectIdFor($projectName) {
    $result = Invoke-AtlasCommand "project list"
    $projects = $result.results
    foreach ($project in $projects) {
        if ($project.name.ToLower() -eq $projectName.ToLower()) {
            return $project.id
        }
    }
    Write-Host "Cannot find a project with name ""$($projectName)"""
    Exit 1
}

function ApplyPropertiesToCommand($command, $props) {
    foreach ($prop in $props.psobject.Properties) {
        $command += " --" + $prop.Name
        if ($prop.Value) {  
            $command += " """ + $prop.Value + """"
        }
    }
    $command
}

function CreateAlert($alert) {
    $command = ApplyPropertiesToCommand "alert settings create" $alert
    Write-Host "Creating alert of type $($alert.event)"
    $result = Invoke-AtlasCommand $command
    $result.id
}

function BackupAlerts() {
    if (Test-Path $fileName) {
        Write-Host "File $($fileName) already exists. Give a different backup file name with parameter -fileName <name of backup file>"
        Exit 1
    }
    $result = Invoke-AtlasCommand ("alert settings list")
    $result | ConvertTo-Json -Depth 10 | Set-Content -Path $fileName
}

function GetProjectId() {
    if ($projectId) {
        $projectId
    }
    else {
        $result = Invoke-AtlasCommand ("config describe " + $atlasProfile)
        $result.project_id
    }
}

function RestoreAlerts($alerts) {
    $createdIds = @()
    $baseUrl = "https://cloud.mongodb.com/api/atlas/v1.0/groups/$(GetProjectId)/alertConfigs"
    $securePassword = ConvertTo-SecureString $privateKey -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($publicKey, $securePassword)
    foreach ($alert in $alerts) {
        # Remove irrelevant information from alert description
        $alert.psobject.Properties.Remove("id")
        $alert.psobject.Properties.Remove("groupId")
        $alert.psobject.Properties.Remove("created")
        $alert.psobject.Properties.Remove("updated")

        # Handle possible config errors (some FTS alerts that are created by default have invalid intervalMin setting of 1)
        $minInterval = $alert.notifications[0].intervalMin
        if ($minInterval -and $minInterval -lt 5) { $alert.notifications[0].intervalMin = 5 }

        # Create alert
        Write-Host "Restoring alert $($alert.eventTypeName)"
        $body = ($alert | ConvertTo-Json -Depth 10)
        $result = Invoke-WebRequest `
            -Method Post `
            -Credential $cred `
            -Headers @{"accept" = "application/json" } `
            -ContentType "application/json" `
            -Body $body `
            -Uri $baseUrl | Select-Object -ExpandProperty Content | ConvertFrom-Json

        # Keep track of created alerts
        $createdIds += $result.id
    }
    $createdIds
}

function DeleteUntouchedAlerts($touchedAlertIds) {
    $existingAlerts = Invoke-AtlasCommand ("alert settings list")
    foreach ($existingAlert in $existingAlerts) {
        if ($existingAlert.id -notin $touchedAlertIds) {
            Invoke-SilentAtlasCommand "alert settings delete $($existingAlert.id) --force"
        }
    }
}

if ($projectName) {
    $projectId = FindProjectIdFor $projectName
}

Switch ($action) {
    "backup" {
        BackupAlerts
    }
    "restore" {
        $alerts = Get-Content -Raw $fileName | ConvertFrom-Json 
        $createdAlertIds = RestoreAlerts $alerts
        DeleteUntouchedAlerts $createdAlertIds
    }
}

