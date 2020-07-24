<#'-----------------------------------------------------------------------------
'Script Name : SnapCenter.psm1  
'Author      : Matthew Beattie
'Email       : mbeattie@netapp.com
'Created     : 2020-07-24
'Description : Function Library for invoking NetApp SnapCenter REST API's.
'Link        : https://www.netapp.com/us/documentation/snapcenter-software.aspx
'Disclaimer  : THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR
'            : IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
'            : WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
'            : PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR 
'            : ANYDIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
'            : DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
'            : GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
'            : INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
'            : WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
'            : NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
'            : THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
'-----------------------------------------------------------------------------#>
#'SnapCenter REST API Functions.
#'------------------------------------------------------------------------------
Function Connect-NrSnapCenter{
   [CmdletBinding()]
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
      [Parameter(Mandatory = $True, HelpMessage = "The Credential to authenticate to SnapCenter")]
      [System.Management.Automation.PSCredential]$Credential
   )
   #'---------------------------------------------------------------------------
   #'Create a hashtable for SnapCenter authentication and convert it to JSON.
   #'---------------------------------------------------------------------------
   [String]$domain   = $credential.GetNetworkCredential().Domain
   [String]$username = $Credential.GetNetworkCredential().Username
   If([String]::IsNullOrEmpty($domain)){
      [String]$usr = $username
   }Else{
      [String]$usr = "$Domain`\$Username"
   }
   [HashTable]$context = @{}
   [HashTable]$user    = @{}
   [HashTable]$attribs = @{}
   [HashTable]$attribs.Add("Name", $usr)
   [HashTable]$attribs.Add("Passphrase", $Credential.GetNetworkCredential().Password)
   [HashTable]$attribs.Add("Rolename", $RoleName)
   [HashTable]$user.Add("User", $attribs)
   [HashTable]$context.Add("UserOperationContext", $user)
   $body = $context | ConvertTo-Json
   #'---------------------------------------------------------------------------
   #'Set the headers for VSC authentication.
   #'---------------------------------------------------------------------------
   $headers = @{
      "Content-Type" = "application/json"
      "Accept"       = "application/json"
   }
   #'---------------------------------------------------------------------------
   #'Login to SnapCenter.
   #'---------------------------------------------------------------------------
   [String]$uri = "https://$Hostname`:$PortNumber/api/$ApiVersion/auth/login`?TokenNeverExpires=$TokenNeverExpires"
   Try{
      $response = Invoke-RestMethod -Uri $uri -ContentType "application/json" -Method POST -Headers $headers -Body $body -ErrorAction Stop
      Write-Host "Authenticated to SnapCenter ""$Hostname"" using URI ""$uri"" as user ""$usr"""
   }Catch{
      Write-Warning -Message $("Failed Authenticating to SnapCenter ""$Hostname"" using URI ""$uri"" as user ""$usr"". Error " + $_.Exception.Message + ". Status Code " + $_.Exception.Response.StatusCode.value__)
      Return $Null;
   }
   #'---------------------------------------------------------------------------
   #'Enumerate the SnapCenter session ID from the response to return.
   #'---------------------------------------------------------------------------
   If($Null -eq $response){
      Write-Warning -Message "Failed Authenticating to SnapCenter ""$Hostname"" using URI ""$uri"" as user ""$usr"""
      Return $Null;
   }
   Return $response;
}#End Function Connect-NrSnapCenter.
#'------------------------------------------------------------------------------
Function ConvertTo-Hashtable{
   [CmdletBinding()]
   [OutputType('hashtable')]
   Param(
      [Parameter(ValueFromPipeline)]
      $InputObject
   )
   #'---------------------------------------------------------------------------
   #'Return null if the input is null. This can happen when calling the function
   #'recursively and a property is null.
   #'---------------------------------------------------------------------------
   If($Null -eq $InputObject){
      Return $Null;
   }
   #'---------------------------------------------------------------------------
   #'Check if the input is an array or collection. If so, we also need to
   #'convert those types into hash tables as well. This function will convert
   #'all child objects into hash tables (if applicable)
   #'---------------------------------------------------------------------------
   If($InputObject -is [System.Collections.IEnumerable] -And $InputObject -IsNot [String]){
      $collection = @(
         ForEach($object In $InputObject){
            ConvertTo-Hashtable -InputObject $object
         }
      )
      #'------------------------------------------------------------------------
      #'Return the array but don't enumerate it because the object may be complex
      #'------------------------------------------------------------------------
      Write-Output -NoEnumerate $collection
   }ElseIf($InputObject -Is [PSObject]){
      #'------------------------------------------------------------------------
      #'If the object has properties that need enumeration Convert it to its own
      #'hash table and return it
      #'------------------------------------------------------------------------
      $hash = @{}
      ForEach($property in $InputObject.PSObject.Properties){
         $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
      }
      Return $hash;
   }Else{
      #'------------------------------------------------------------------------
      #'If the object isn't an array, collection, or other object, it's already a
      #'hash table so just return it.
      #'------------------------------------------------------------------------
      Return $InputObject;
   }
}#End Function ConvertTo-Hashtable.
#'------------------------------------------------------------------------------
Function Get-NrHosts{
   [CmdletBinding()]
   Param(
      [Parameter(Mandatory = $True, HelpMessage = "The SnapCenter hostname, IP Address or FQDN")]
      [ValidateNotNullOrEmpty()]
      [String]$Hostname,
      [Parameter(Mandatory = $False, HelpMessage = "The SnapCenter Port Number. Default is 8146")]
      [Int]$PortNumber = 8146,
      [Parameter(Mandatory = $True, HelpMessage = "The SnapCenter Authentication Token")]
      [ValidateNotNullOrEmpty()]
      [String]$Token,
      [Parameter(Mandatory = $False, HelpMessage = "The SnapCenter API Version. Default is '4.2'")]
      [String]$ApiVersion = "4.2",
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
      [String]$Status
   )
   #'---------------------------------------------------------------------------
   #'Set the headers for VSC authentication.
   #'---------------------------------------------------------------------------
   $headers = @{
      "Token"  = $Token
      "Accept" = "application/json"
   }
   #'---------------------------------------------------------------------------
   #'Set the URI to enumerate the SnapCenter Hosts.
   #'---------------------------------------------------------------------------
   [String]$uri = "https://$Hostname`:$PortNumber/api/$ApiVersion/hosts`?"
   [Bool]$query = $False;
   If($PluginInfo){
      [String]$uri += "&IncludePluginInfo=$PluginInfo"
      [Bool]$query = $True
   }
   If($VerificationServerInfo){
      [String]$uri += "&IncludeVerificationServerInfo=$VerificationServerInfo"
      [Bool]$query = $True
   }
   If($OperatingSystem){
      [String]$uri += "&OperatingSystemName=$VerificationServerInfo"
      [Bool]$query = $True
   }
   If($Status){
      [String]$uri += "&Status=$Status"
      [Bool]$query = $True
   }
   If(-Not($query)){
      [String]$uri = $uri.SubString(0, ($uri.Length -1))
   }Else{
      [String]$uri = $uri.Replace("?&", "?")
   }
   #'---------------------------------------------------------------------------
   #'Enumerate the Hosts.
   #'---------------------------------------------------------------------------
   Try{
      $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ErrorAction Stop
      Write-Host "Enumerated Hosts on SnapCenter ""$Hostname"" using URI ""$uri"""
   }Catch{
      Write-Warning -Message $("Failed enumerating Hosts on SnapCenter ""$Hostname"" using URI ""$uri"". Error " + $_.Exception.Message + ". Status Code " + $_.Exception.Response.StatusCode.value__)
   }
   Return $response;
}#End Function Get-NrHosts.
#'------------------------------------------------------------------------------
