function Connect-Exchange {
    
    <#
    .SYNOPSIS
    Connects to On-Premises Microsoft Exchange Server
    
    .DESCRIPTION
    Connects to On-Premises Microsoft Exchange Server. By default, prefixes all commands with, "OnPrem".
    For example, Get-OnPremMailbox. Use the NoPrefix parameter to prevent this.
    
    .PARAMETER ExchangeServer
    The Exchange Server name to connect to
    
    .PARAMETER NoPrefix
    Prevents the use of "OnPrem" prefix. If this parameter is used, commands will be the standard commands.
    For example, Get-Mailbox instead of Get-OnPremMailbox
    
    .PARAMETER DeleteExchangeCreds
    Deletes the saved/encrypted credentials, previously saved by this script.
    Helpful when incorrect credentials were entered previously.
    
    .PARAMETER ViewEntireForest
    Sets the scope of the current session to the entire forest
    
    .PARAMETER NoMessageForPS2
    Use this when using PowerShell 2
    
    .EXAMPLE
    Connect-Exchange -ExchangeServer EXCH01 -ViewEntireForest -NoPrefix
    
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param 
    (
        [Parameter(Mandatory = $False)]
        [string] $ExchangeServer,

        [Parameter(Mandatory = $False)]
        [Switch] $NoPrefix,

        [Parameter(Mandatory = $False)]
        [Switch] $DeleteExchangeCreds,
        
        [Parameter(Mandatory = $False)]
        [Switch] $ViewEntireForest,

        [Parameter(Mandatory = $False)]
        [Switch] $NoMessageForPS2
        
    )

    $RootPath = $env:USERPROFILE + "\ps\"
    $KeyPath = $Rootpath + "creds\"
    $User = $env:USERNAME

    while (!(Test-Path ($RootPath + "$($user).EXCHServer"))) {
        Select-ExchangeServer
    }
    $ExchangeServer = Get-Content ($RootPath + "$($user).EXCHServer")
    
    # Delete invalid or unwanted credentials
    if ($DeleteExchangeCreds) {
        Try {
            Remove-Item ($KeyPath + "$($user).ExchangeCred") -ErrorAction Stop
        }
        Catch {
            $_
            Write-Host "Unable to Delete Exchange Password"
        }
        Try {
            Remove-Item ($KeyPath + "$($user).uExchangeCred") -ErrorAction Stop
        }
        Catch {
            $_
            Write-Host "Unable to Delete Exchange Username"
        }
        
    }
    # Create KeyPath Directory
    if (!(Test-Path $KeyPath)) {
        try {
            New-Item -ItemType Directory -Path $KeyPath -ErrorAction Stop | Out-Null
        }
        catch {
            throw $_.Exception.Message
        }           
    }
    if (Test-Path ($KeyPath + "$($user).ExchangeCred")) {
        $PwdSecureString = Get-Content ($KeyPath + "$($user).ExchangeCred") | ConvertTo-SecureString
        $UsernameString = Get-Content ($KeyPath + "$($user).uExchangeCred")
        $Credential = Try {
            New-Object System.Management.Automation.PSCredential -ArgumentList $UsernameString, $PwdSecureString -ErrorAction Stop 
        }
        Catch {
            if ($_.exception.Message -match '"userName" is not valid. Change the value of the "userName" argument and run the operation again') {
                Connect-Exchange -DeleteExchangeCreds
                Write-Host "***************************************************************************** " -foregroundcolor "darkblue" -backgroundcolor "white"
                Write-Host "                    Bad Username.                                             " -foregroundcolor "darkblue" -backgroundcolor "white"
                Write-Host "          Please try your last command again...                               " -foregroundcolor "darkblue" -backgroundcolor "white"
                Write-Host "...you will be prompted to enter your on-premises Exchange credentials again. " -foregroundcolor "darkblue" -backgroundcolor "white"
                Write-Host "***************************************************************************** " -foregroundcolor "darkblue" -backgroundcolor "white"
                Break
            }
        }
    }
    else {
        if (!$NoMessageForPS2) {
            $Credential = Get-Credential -Message "Enter a username and password for ONPREM EXCHANGE"   
        }
        else {
            $Credential = Get-Credential
        }
        if ($Credential.Password) {
            $Credential.Password | ConvertFrom-SecureString | Out-File ($KeyPath + "$($user).ExchangeCred") -Force
        }
        else {
            Connect-Exchange -DeleteExchangeCreds
            Write-Host "***************************************************************************** " -foregroundcolor "darkblue" -backgroundcolor "white"
            Write-Host "                    No Password Present.                                      " -foregroundcolor "darkblue" -backgroundcolor "white"
            Write-Host "          Please try your last command again...                               " -foregroundcolor "darkblue" -backgroundcolor "white"
            Write-Host "...you will be prompted to enter your on-premises Exchange credentials again. " -foregroundcolor "darkblue" -backgroundcolor "white"
            Write-Host "***************************************************************************** " -foregroundcolor "darkblue" -backgroundcolor "white"
            Break
        }
        $Credential.UserName | Out-File ($KeyPath + "$($user).uExchangeCred")
    }    
    Try {
        $Session = New-PSSession -Name "OnPremExchange" -ConfigurationName Microsoft.Exchange -ConnectionUri ("http://" + $ExchangeServer + "/PowerShell/") -Authentication Kerberos -Credential $Credential -ErrorAction Stop
    }
    Catch {
        If ($_.exception.Message -match 'user name or password') {
            Connect-Exchange -DeleteExchangeCreds
            Write-Host "***************************************************************************** " -foregroundcolor "darkblue" -backgroundcolor "white"
            Write-Host "                    Bad Credentials.                                          " -foregroundcolor "darkblue" -backgroundcolor "white"
            Write-Host "          Please try your last command again...                               " -foregroundcolor "darkblue" -backgroundcolor "white"
            Write-Host "...you will be prompted to enter your on-premises Exchange credentials again. " -foregroundcolor "darkblue" -backgroundcolor "white"
            Write-Host "***************************************************************************** " -foregroundcolor "darkblue" -backgroundcolor "white"
            Break
        }
    }
    If (!$NoPrefix) {
        $SessionModule = Import-PSSession -AllowClobber -DisableNameChecking -Prefix 'OnPrem' -Session $Session
        $Null = Import-Module $SessionModule -Global -Prefix "OnPrem" -DisableNameChecking -Force
        if ($ViewEntireForest) {
            Set-OnPremADServerSettings -ViewEntireForest:$True
        }
        Write-Host "********************************************************************" -foregroundcolor "darkgreen" -backgroundcolor "white"
        Write-Host "        You are now connected to On-Premises Exchange               " -foregroundcolor "darkgreen" -backgroundcolor "white"
        Write-Host "          All commands are pre-pended with OnPrem, for example:     " -foregroundcolor "darkgreen" -backgroundcolor "white"
        Write-Host "               Get-Mailbox       is      Get-OnPremMailbox          " -foregroundcolor "darkgreen" -backgroundcolor "white"
        Write-Host " This is to prevent overlap of commands between Office 365 and EXO  " -foregroundcolor "darkgreen" -backgroundcolor "white"
        Write-Host "********************************************************************" -foregroundcolor "darkgreen" -backgroundcolor "white"
    }
    else {
        $SessionModule = Import-PSSession -AllowClobber -DisableNameChecking -Session $Session
        $Null = Import-Module $SessionModule -Global -DisableNameChecking -Force
        if ($ViewEntireForest) {
            Set-ADServerSettings -ViewEntireForest:$True
        }
        Write-Host "********************************************************************" -foregroundcolor "darkgreen" -backgroundcolor "white"
        Write-Host "        You are now connected to On-Premises Exchange               " -foregroundcolor "darkgreen" -backgroundcolor "white"
        Write-Host "********************************************************************" -foregroundcolor "darkgreen" -backgroundcolor "white"
    }
}
    