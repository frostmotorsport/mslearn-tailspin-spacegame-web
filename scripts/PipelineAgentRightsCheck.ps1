# Azure DevOps Pipeline PowerShell Script

# Sets a Pipeline variable to true or false depending on whether or not the agent is running with admin rights.
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

Function SetPipelineVariable {
Param ([string] $VariableName, [string] $VariableValue)
    Write-Host "Setting variable '$VariableName' to '$VariableValue'"
    Write-Host "##vso[task.setvariable variable=$VariableName]$VariableValue"
}

Function SvcCtrlCheck {

    $AgentSID = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
#cmd line must be sc.exe, otherwise "sc" by itself is something different....
    $dACL = sc.exe sdshow $ServiceName 

    Write-Host "Checking Service Control ACL for Agent Service Account with SID '$AgentSID' in DACL '$dACL' for Service '$ServiceName'"
    
    if (($dACL | select-string -Pattern $AgentSID) -eq 'NULL') {
        Write-Error "User SID '$AgentSID' does not have Svc ACL"
    }
    else {
        Write-Host "Agent has ACL already, no action required"
        $hasacl = 1
        #Exit 0
    }
}

# Main
write-host "check if agent has svc rights"
SvcCtrlCheck

write-host "check if agent has admin rights"
$isadmin = (AdminCheck)
SetPipelineVariable -VariableName "agentHasAdminRights" -VariableValue $isadmin


write-host "if elevated and no svc rights, lets set them"
if (($hasacl -eq 0) -and ($isadmin -eq "True")) {
    write-host "set svc rights"
    sc.exe sdset $ServiceName "D:(A;;RPWPDTRC;;;{$AgentSID}(A;;CCLCSWLOCRRC;;;AU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWRPWPDTLOCRRC;;;SY)"
}
