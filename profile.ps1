#region PSDefaultParams
$PSDefaultParameterValues = @{
	'*F5*:Credential'             = $MyAdminCred
	'*AWS*:Credential'            = $MyUserCred
	'Get-ChildItem:Force'         = $True
	'Receive-Job:Keep'            = $True
	'Test-Connection:Quiet'       = $True
	'Test-Connection:Count'       = '1'
}
#endregion PSDefaultParams
