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
    [Parameter(Mandatory)] [string]$clusterName, # Name of cluster to back up
    [Parameter(Mandatory)] [string]$description, # Description for the snapshot
    [string]$atlasProfile, # Name of Atlas CLI profile to use
    [string]$projectName, # Name of project to use
    [string]$projectId # ID of project to use
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
    # Write-Host $fullCommand
    $result = $fullCommand | Invoke-Expression | ConvertFrom-Json

    if (!$result) {
        Write-Host "No result received. Fatal error."
        Exit 1
    }
    if ($result.results) {
        $result.results
    }
    else {
        $result
    }
}

function FindProjectIdFor($projectName) {
    $projects = Invoke-AtlasCommand "project list"
    foreach ($project in $projects) {
        if ($project.name.ToLower() -eq $projectName.ToLower()) {
            return $project.id
        }
    }
    Write-Host "Cannot find a project with name ""$($projectName)"""
    Exit 1
}

function ListSnapshots() {
    Invoke-AtlasCommand "backups snapshots list $($clusterName)"
}

function CreateSnapshot() {
    Invoke-AtlasCommand "backups snapshots create $($clusterName) --desc $($description)"
}

function DescribeSnapshot([string]$snapshotId) {
    Invoke-AtlasCommand "backups snapshots describe $($snapshotId) --clusterName $($clusterName)"
}

function ListRestoreOperations() {
    Invoke-AtlasCommand "backups restore list $($clusterName)"
}

function CreateRestoreOperation() {
    Invoke-AtlasCommand "backups restore start download --clusterName $($clusterName) --snapshotId $($snapshotId)"
}

function DescribeRestoreOperation([string]$restoreId) {
    Invoke-AtlasCommand "backups restore describe $($restoreId) --clusterName $($clusterName)"
}

if ($projectName) {
    $projectId = FindProjectIdFor $projectName
}

Write-Host "Check for backup snapshot in progress"
$result = ListSnapshots
foreach ($res in $result) {
    # Note! For sharded systems this check needs to look a bit different
    if (($res.status -eq "inProgress") -and ($res.replicaSetName -eq $clusterName)) {
        $snapshotId = $res.id
        Write-Host "Found backup in progress $($snapshotId)"
        break
    }
}

if (!($snapshotId)) {
    Write-Host "Creating new backup snapshot"
    $result = CreateSnapshot
    $snapshotId = $result.id
}

Write-Host "Waiting for backup to complete"
while ($true) {
    $result = DescribeSnapshot $snapshotId
    if ($result.status -eq "completed") {
        Write-Host "Backup completed"
        break
    }
    Write-Host "Waiting..."
    Start-Sleep -Seconds 30
}

Write-Host "Check if restore operation for download exists for snapshot"
$result = ListRestoreOperations
foreach ($res in $result) {
    if (($res.deliveryType -eq "download") -and ($res.snapshotId -eq $snapshotId)) {
        $restoreId = $res.id
        Write-Host "Restore download operation $($restoreId) exists, using that."
        break
    }
}

if (!($restoreId)) {
    Write-Host "Creating restore operation for download"
    $result = CreateRestoreOperation $snapshotId
    $restoreId = $result.id
}

Write-Host "Waiting for file creation to complete"
while ($true) {
    $result = DescribeRestoreOperation $restoreId
    $deliveryUrls = $result.deliveryUrl
    if ($deliveryUrls) {
        break
    }
    Write-Host "Waiting..."
    Start-Sleep -Seconds 30
}

Write-Host "Downloading snapshot file(s) $($deliveryUrls)"
foreach ($deliveryUrl in $deliveryUrls) {
    # Get last part of URL to be used as file path
    $fileName = [System.IO.Path]::GetFileName($deliveryUrl)
    Invoke-WebRequest $deliveryUrl -OutFile $fileName
}
Write-Host "Download complete"
