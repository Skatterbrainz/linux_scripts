[CmdletBinding()]
param()
Set-PSResourceRepository -Name PSGallery -Trusted
$modules = (
'Az','Microsoft.Graph','Microsoft.Entra',
'ExchangeOnlineManagement',
'PnP.PowerShell','ImportExcel',
'LinuxTools','PSReadLine',
'AWS.Tools.Common',
'Microsoft.PowerShell.ConsoleGuiTools',
'Microsoft.PowerShell.SecretManagement',
'SecretManagement.LinuxKeyring',
'PSDates','Helium','osquery','psSearchGitHub'
)
Install-PSResource -Name $modules -Repository PSGallery -TrustRepository
