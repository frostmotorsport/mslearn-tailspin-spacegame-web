# Azure DevOps Pipeline PowerShell Script

# Checks and Sets user rights using Service Control Manager.

Param (
    [Parameter(Mandatory)]
    [string] $ServiceName
)

$dACL = ''
$hasacl = 0
$AgentSID = ''

Function AdminCheck {
    try {
        $agentWithAdminRights = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    }
	catch {
        Write-Error "Error encountered while attempting to check for admin rights.`n$Error[0]"
	}
	return ($agentWithAdminRights.ToString())
}

Function SvcCtrlCheck {

    $AgentSID = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
#cmd line must be sc.exe, otherwise "sc" by itself is something different....
    $dACL = sc.exe sdshow $ServiceName 

    Write-Host "Checking Service Control ACL for Agent Service Account with SID '$AgentSID' in DACL '$dACL' for Service '$ServiceName'"
    
    if (($dACL | select-string -Pattern $AgentSID) -eq $null) {
        Write-Warning "User SID '$AgentSID' does not have Svc ACL"
    }
    else {
        Write-Host "Agent has ACL already, no action required"
        $hasacl = 1
        }
}

# Main
write-host "check if agent has svc rights"
SvcCtrlCheck

write-host "check if agent has admin rights"
$isadmin = (AdminCheck)

write-host "if no svc rights, lets set them"

 $dACL = sc.exe sdshow $ServiceName 
 $AgentSID = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
 $newACL = "$dACL(A;;RPWPDTRC;;;$AgentSID)"
 write-host $newACL
 write-host "IsAdmin is $isadmin and hasACL is $hasacl"

if (($hasacl -eq 0) -and ($isadmin -eq "True")) {
    write-host "setting service rights for Agent User"
    sc.exe sdset $ServiceName $newACL
    }
    else { 
    write-host "Exiting no action" 
    }