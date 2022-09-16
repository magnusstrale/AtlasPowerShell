# AtlasPowerShell
Powershell scripts for administering Atlas

## Prerequisites
Atlas CLI
API keys
Atlas profile
Access to API keys for alert restore and backup/restore of audit log configuration.

## Downloading backup snapshots with backup_atlas.ps1

Create a snapshot and download it to the machine where this script is executed.

**Synopsis**

.\backup_atlas.ps1 -clusterName <string> -description <string> [[-atlasProfile] <string>] [[-projectName] <string>] [[-projectId] <string>] [<CommonParameters>]

| Parameter     | Description
| ---------     | ----------- 
| -clusterName  | Name of the cluster to backup. (mandatory)
| -description  | Description for the snapshot that gets created. (mandatory)
| -atlasProfile | The profile to use for for Atlas CLI commands. (default is default Atlas CLI profile)
| -projectId    | The ID of the project that contains the cluster to backup. Overrides information in profile. (default is value from Atlas CLI profile)
| -projectName  | The name of the project that contains the cluster to backup. Overrides value for -profileId if both given.

## Manage project alers with alerts_atlas.ps1

## Manage backup policy with backupplan.ps1

## Create Atlas setup for a team / application / environment
First ensure you have the necessary config files for the intended environment. You need:
- Alerts_[environment].json
- BackupPlan_[environment].json
- AuditLogConfig_[environment].json

### Create Alerts.json
Run the script alerts_atlas.ps1 with the backup option and output to a file with the correct name based on the environment. For example to create an alerts config file from project GC-PAY-PROD to be used as a template for setting up Atlas in UAT environment (note that alerts are defined on projects), run the following command:

    ./alerts_atlas.ps1 backup -projectName GC-PAY-PROD -fileName Alerts_UAT.json

### Create BackupPlan.json
Run the script backupplan_atlas.ps1 with the backup option and output to a file with the correct name based on the environment. For example to create a backup plan config file from project GCPAYPROD, cluster GC-PAY-PROD (note that backup plan is defined on cluster) to be used as a template for setting up Atlas in UAT environment, run the following command:

    ./backupplan_atlas.ps1 backup -projectName GC-PAY-PROD -clusterName GCPAYPROD -fileName BackupPlan_UAT.json

### Create AuditLogConfig.json
Run the script auditlog_atlas.ps1 with the backup option and output to a file with the correct name based on the environment. Accessing the audit log configuration requires the script to use the API keys.

For example to create an audit log config file from project GCPAYPROD (note that auditing configuration is defined on projects) to be used as a template for setting up Atlas in UAT environment, run the following command:

    ./auditlog_atlas.ps1 backup -projectName GC-PAY-PROD -fileName AuditLogConfig_UAT.json -publicKey ljewcykn -privateKey b4806a90-76d0-41d9-a5ff-22cb58d7e14f

### Create Atlas setup
The script create_atlas.ps1 will create an entire Atlas environment for you, based on parameters on the command line as well as configuration files with associated data. The process will set up the following:
- A new project
- Alerts in that project according to config file
- A cluster, configured as a three-node replica set
- A backup plan according to config file
- A database user
- A private endpoint (manual configuration will be needed post-setup in your cloud provider)
- Audit log according to config file

**Synopsis**

.\create_atlas.ps1 -team &lt;string&gt; -service &lt;string&gt; -environment &lt;string&gt; -publicKey &lt;string&gt; -privateKey &lt;string&gt; [-tier &lt;string&gt;] [-region &lt;string&gt;] [-provider &lt;string&gt;] [-diskSizeGB &lt;int&gt;] [-mdbVersion &lt;string&gt;] [-role &lt;string&gt;] [-atlasProfile &lt;string&gt;]

| Parameter     | Description
| ---------     | ----------- 
| -team         | Name of the team that owns this setup (mandatory)
| -serivce      | Name of the service/application that will use this setup (mandatory)
| -environment  | Name of the environment where to create this setup (mandatory)
| -publicKey    | The public part of the API key used to access Atlas (mandatory)
| -privateKey   | The private part of the API key used to access Atlas (mandatory)
| -tier         | The size of the Atlas cluster to create (default M10)
| -region       | The region where to create the Atlas cluster. Values depends on your cloud provider. (default UK_SOUTH)
| -provider     | The cloud provider to use for your cluster. Valid values are AWS or AZURE. (default AZURE)
| -diskSizeGB   | The amount of disk spce to allocate for your cluster. Should rarely need to be used. (default depends on tier)
| -mdbVersion   | Version of MongoDB to run on your cluster. Valid values are 4.2, 4.4, 5.0 and 6.0. (default 5.0)
| -role         | Role that the database user is assigned to. (default readWriteAnyDatabase@admin)
| -atlasProfile | The profile to use for for Atlas CLI commands.

The -team, -service and -environment parameters will be used for naming various artifacts in the setup process. Assuming we have the following command line:

    ./create_atlas.ps1 -team GC -service APP -environment UAT -publicKey ljewcykn -privateKey b4806a90-76d0-41d9-a5ff-22cb58d7e14f

- Project name will be GC-APP-UAT
- Cluster name will be GCAPPUAT
- Database user name will be svc_uat_gcapp

The -environment name will also be used to determine which configuration files to use for creating alerts, configuring backup plan and setting audit log configuration. Again using the example above with -environment UAT, the following configuration files will be used:

| Type                  | File name
| ----                  | ---------
| Alerts                | Alerts_UAT.json
| Backup plan           | BackupPlan_UAT.json
| Audit configuration   | AuditLogConfig_UAT.log

**Note that the file names are case sensitive**

### Usage Examples
Creates a new setup in AZURE, region UK_SOUTH with a M10 cluster for UAT environment. Profile information in the Atlas CLI profile Demo will be used. Note! Ensure that the API keys registered in the selected profile matches the API keys given on the command line.

    ./create_atlas.ps1 -team GC -service APP -environment UAT -publicKey ljewcykn -privateKey b4806a90-76d0-41d9-a5ff-22cb58d7e14f -atlasProfile Demo

Creates a new setup in AWS, region EU_NORTH_1 with a M30 cluster for prod environment. Profile information in the Atlas CLI profile Production will be used

    ./create_atlas.ps1 -team GC -service APP -environment UAT -publicKey abacggfd -privateKey b4806a90-9999-41d9-a5ff-22cb9872124f -atlasProfile Production -provider AWS -region EU_NORTH_1 -tier M30