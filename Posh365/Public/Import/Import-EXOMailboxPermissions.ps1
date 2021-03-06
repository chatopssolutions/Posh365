function Import-EXOMailboxPermissions { 
    <#
    .SYNOPSIS
    Applies permissions to Exchange Online Mailboxes
    
    .DESCRIPTION
    Applies permissions to Exchange Online Mailboxes Full Access will automap the mailbox
    In other words, Outlook automatically opens the mailbox where the user is assigned Full Access permission.

    .EXAMPLE
    Import-Csv .\contoso-EXOPermissions_All.csv | Import-EXOMailboxPermissions

    #>

    [CmdletBinding()]
    Param 
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Permission
    )
    Begin {

    }
    Process {
        ForEach ($CurPermission in $Permission) {
            $type = $CurPermission.Permission
            switch ( $type ) {
                SendAs {
                    Write-Verbose "Granting $($CurPermission.Granted) $($CurPermission.Permission) permission over $($CurPermission.Object)"
                    Add-RecipientPermission -Identity $CurPermission.ObjectPrimarySMTP -Trustee $CurPermission.GrantedPrimarySMTP -AccessRights SendAs -Confirm:$False
                }
                SendOnBehalf {
                    Write-Verbose "Granting $($CurPermission.Granted) $($CurPermission.Permission) permission over $($CurPermission.Object)"
                    Set-Mailbox $CurPermission.ObjectPrimarySMTP -GrantSendOnBehalfTo $CurPermission.GrantedPrimarySMTP -Confirm:$False
                }
                FullAccess {
                    Write-Verbose "Granting $($CurPermission.Granted) $($CurPermission.Permission) permission over $($CurPermission.Mailbox)"
                    Add-MailboxPermission -Identity $CurPermission.ObjectPrimarySMTP -User $CurPermission.GrantedPrimarySMTP -AccessRights FullAccess -InheritanceType All -Confirm:$False
                }
            }
        }
    }
    End {
        
    }
}
