# Azure DevOps Pipeline PowerShell Script

# Checks and Sets user rights using Service Control Manager.

Param (
    [Parameter(Mandatory)][string] $ServiceName
    )

Set-Variable -name dACL -Value '' -Scope Global
Set-Variable -name acl -Value 0 -Scope Global
Set-Variable -name AgentSID -Value '' -Scope Global  

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

    $Global:AgentSID = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
#cmd line must be sc.exe, otherwise "sc" by itself is something different....
    $Global:dACL = sc.exe sdshow $ServiceName 

    Write-Host "Checking Service Control ACL for Agent Service Account with SID '$Global:AgentSID' in DACL '$Global:dACL' for Service '$ServiceName'"
    
    if (($Global:dACL | select-string -Pattern $Global:AgentSID) -eq $null) {
        Write-Warning "User SID '$Global:agentSID' does not have Svc ACL"
    }
    else {
        Write-Host "Agent has ACL already, no action required"
        $Global:acl = 1
        }
    return $Global:acl
}

# Main
write-host "check if agent has svc rights"
$hasACL = (SvcCtrlCheck)

write-host "check if agent has admin rights"
$isadmin = (AdminCheck)

 write-host "if no svc rights, lets set them"
 
 #the following are for diag, so feel free to get rid of them once this is in production
 write-host "Checking $ServiceName is in local dACL $Global:dACL with agentSID $Global:agentSID"

 $newSEC = "(A;;RPWPDTRC;;;$Global:AgentSID)"
 $newACL = "$($Global:dACL[1].substring(0,2))$newSEC$($Global:dACL[1].substring(2,$Global:dACL[1].length-2))"

 write-host $newACL
 write-host "Service Name is $servicename"
 write-host "IsAdmin is $isadmin and hasACL is $hasacl"

if (($hasacl -eq 0) -and ($isadmin -eq "True")) {
    write-host "setting service rights for Agent User"
    sc.exe sdset $ServiceName $newACL
    }
    else { 
    write-host "Exiting no action" 
    }