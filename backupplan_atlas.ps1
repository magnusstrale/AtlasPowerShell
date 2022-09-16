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

param(
    [ValidateSet("backup", "restore")]
    [string]$action = "restore",
    [Parameter(Mandatory)] [string]$clusterName,
    [string]$fileName = "BackupPlan.json",
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
    if ($debug) {
        Write-Host $fullCommand
    }
    $fullCommand | Invoke-Expression | ConvertFrom-Json
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

function GetPolicyItem($frequencyType, $backupPlan) {
    $policyItems = $backupPlan.policies[0].policyItems
    foreach ($policyItem in $policyItems) {
        if ($policyItem.frequencyType -eq $frequencyType) {
            return $policyItem
        }
    }
    Write-Host "Bad plan detected, missing frequencyType $($frequencyType). Offending plan: $($backupPlan)"
}

function EqualPolicyItem($newPolicyItem, $existingPolicyItem)
{
     if ($newPolicyItem.frequencyInterval -ne $existingPolicyItem.frequencyInterval) { return $false }
     if ($newPolicyItem.retentionUnit -ne $existingPolicyItem.retentionUnit) { return $false }
     if ($newPolicyItem.retentionValue -ne $existingPolicyItem.retentionValue) { return $false }
     $true
}

function UpdatePolicy($command, $frequencyType, $newBackupPlan, $existingBackupPlan) {
    $newPolicyItem = GetPolicyItem $frequencyType $newBackupPlan
    $existingPolicyItem = GetPolicyItem $frequencyType $existingBackupPlan

    if (EqualPolicyItem $newPolicyItem $existingPolicyItem) { return $command }

    $existingPolicyId = $existingBackupPlan.policies[0].id
    $command += " --policy $($existingPolicyId),$($existingPolicyItem.id),$($frequencyType),$($newPolicyItem.frequencyInterval),$($newPolicyItem.retentionUnit),$($newPolicyItem.retentionValue)"
    $command
}

function RestoreBackupPlan($newBackupPlan) {
    $existingBackupPlan = Invoke-AtlasCommand "backup schedule describe $($clusterName)"
    
    $command = "backup schedule update --clusterName $($clusterName)"
    $originalState = $command
    if ($newBackupPlan.referenceHourOfDay -ne $existingBackupPlan.referenceHourOfDay) {
        $command += " --referenceHourOfDay $($newBackupPlan.referenceHourOfDay)"
    }
    if ($newBackupPlan.referenceMinuteOfHour -ne $existingBackupPlan.referenceMinuteOfHour) {
        $command += " --referenceMinuteOfHour $($newBackupPlan.referenceMinuteOfHour)"
    }
    if ($newBackupPlan.restoreWindowDays -ne $existingBackupPlan.restoreWindowDays) {
        $command += " --restoreWindowDays $($newBackupPlan.restoreWindowDays)"
    }

    foreach ($frequencyType in ("hourly", "daily", "weekly", "monthly"))
    {
        # BUGBUG - There seems to be issues with weekly frequencyInterval, it only accepts 1 (Monday) and 7 (Sunday) - https://jira.mongodb.org/browse/PRODTRIAGE-3228
        $command = UpdatePolicy $command $frequencyType $newBackupPlan $existingBackupPlan
    }

    if ($originalState -ne $command) {
        $result = Invoke-AtlasCommand $command
    }
}

function BackupBackupPlan($fileName) {
    if (Test-Path $fileName) {
        Write-Host "File $($fileName) already exists. Give a different backup file name."
        Exit 1
    }
    $result = Invoke-AtlasCommand "backup schedule describe $($clusterName)"
    $result | ConvertTo-Json -Depth 10 | Set-Content -Path $fileName
}

if ($projectName) {
    $projectId = FindProjectIdFor $projectName
}

Switch ($action) {
    "backup" {
        BackupBackupPlan $fileName
    }
    "restore" {
        $config = Get-Content -Raw $fileName | ConvertFrom-Json
        RestoreBackupPlan $config
    }
}

