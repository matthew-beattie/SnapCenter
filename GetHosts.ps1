Param(
   [Parameter(Mandatory = $True, HelpMessage = "The SnapCenter hostname, IP Address or FQDN")]
   [ValidateNotNullOrEmpty()]
   [String]$Hostname,
   [Parameter(Mandatory = $False, HelpMessage = "The SnapCenter Port Number. Default is 8146")]
   [Int]$PortNumber = 8146,
   [Parameter(Mandatory = $False, HelpMessage = "The SnapCenter Role name. Default Valid role names are 'SnapCenterAdmin', 'App Backup and Clone Admin', 'Backup and Clone Viewer' or 'Infrastructure Admin'. Custom role names cane be provided. Default is 'SnapCenterAdmin'")]
   [ValidateSet("SnapCenterAdmin","App Backup and Clone Admin","Backup and Clone Viewer","Infrastructure Admin")]
   [String]$Rolename = "SnapCenterAdmin",
   [Parameter(Mandatory = $False, HelpMessage = "The SnapCenter API Version. Default is '4.2'")]
   [String]$ApiVersion = "4.2",
   [Parameter(Mandatory = $False, HelpMessage = "The SnapCenter Token expiry. Default is 'False' (Authentication Token will expire)")]
   [ValidateSet("true", "false")]
   [String]$TokenNeverExpires = "false",
   [Parameter(Mandatory = $False, HelpMessage = "If specified the Host Plugin information will be returned. Default is 'False'")]
   [ValidateSet("true", "false")]
   [String]$PluginInfo = "false",
   [Parameter(Mandatory = $False, HelpMessage = "If specified the Verification Server information will be returned. Default is 'False'")]
   [ValidateSet("true", "false")]
   [String]$VerificationServerInfo = $False,
   [Parameter(Mandatory = $False, HelpMessage = "The Host Operating System")]
   [ValidateSet("Windows","Linux","Solaris","Mac","VSphere")]
   [String]$OperatingSystem,
   [Parameter(Mandatory = $False, HelpMessage = "The Host Operating System")]
   [ValidateSet("HostStatusUnknown","HostDown","HostUp","HostInstallingPlugin","HostPluginUpgradeNeeded","HostPluginIncompatible","HostUnInstallingPlugin")]
   [String]$Status,
   [Parameter(Mandatory = $True, HelpMessage = "The Credential to authenticate to SnapCenter")]
   [System.Management.Automation.PSCredential]$Credential
)
#'------------------------------------------------------------------------------
#'Import the AIQUM Module.
#'------------------------------------------------------------------------------
Import-Module .\SnapCenter.psm1
Write-Host "Imported Module .\SnapCenter.psm1"
#'------------------------------------------------------------------------------
#'Set the certificate policy and TLS version.
#'------------------------------------------------------------------------------
Add-Type @"
   using System.Net;
   using System.Security.Cryptography.X509Certificates;
   public class TrustAllCertsPolicy : ICertificatePolicy {
   public bool CheckValidationResult(
   ServicePoint srvPoint, X509Certificate certificate,
   WebRequest request, int certificateProblem) {
      return true;
   }
}
"@
[System.Net.ServicePointManager]::SecurityProtocol  = [System.Net.SecurityProtocolType]'Tls12'
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
#'------------------------------------------------------------------------------
#'Authenticate to SnapCenter.
#'------------------------------------------------------------------------------
[String]$command = "Connect-NrSnapCenter -Hostname $Hostname "
If($PorNumber){
   [String]$command += "-PortNumber $PortNumber "
}
If($Rolename){
   [String]$command += "-Rolename '$Rolename' "
}
If($ApiVersion){
   [String]$command += "-ApiVersion '$ApiVersion' "
}
If($TokenNeverExpires){
   [String]$command += "-TokenNeverExpires '$TokenNeverExpires' "
}
[String]$command += "-Credential `$Credential -ErrorAction Stop"
Try{
   $auth = Invoke-Expression -Command $command -ErrorAction Stop
   Write-Host "Executed Command`: $command" -ForegroundColor Cyan
}Catch{
   Write-Warning -Message $("Failed Executing Command`: $command. Error " + $_.Exception.Message)
   Break;
}
[String]$Token = $Null;
If($Null -ne $auth){
   [String]$Token = $auth.User.Token
}
If([String]::IsNullOrEmpty($Token)){
   Write-Warning -Message "Failed Authenticating to SnapCenter ""$Hostname"""
   Break;
}
#'------------------------------------------------------------------------------
#'Enumerate the SnapCenter Hosts.
#'------------------------------------------------------------------------------
[String]$command = "Get-NrHosts -Hostname $Hostname "
If($PortNumber){
   [String]$command += "-PortNumber $PortNumber "
}
If($PluginInfo){
   [String]$command += "-PluginInfo '$PluginInfo' "
}
If($VerificationServerInfo){
   [String]$command += "-VerificationServerInfo '$VerificationServerInfo' "
}
If($OperatingSystem){
   [String]$command += "-OperatingSystem '$OperatingSystem' "
}
If($Status){
   [String]$command += "-Status '$Status' "
}
[String]$command += "-Token `$Token -ErrorAction Stop"
#'------------------------------------------------------------------------------
#'Enumerate the Hosts.
#'------------------------------------------------------------------------------
Try{
   $hosts = Invoke-Expression -Command $command -ErrorAction Stop #| ConvertTo-HashTable
   Write-Host "Executed Command`: $command" -ForegroundColor Cyan
}Catch{
   Write-Warning -Message $("Failed Executing Command`: $command. Error " + $_.Exception.Message)
}
#$hosts.HostInfo["Hosts"]
#$hosts | ConvertTo-Json
$hosts.HostInfo.Hosts
#'------------------------------------------------------------------------------
