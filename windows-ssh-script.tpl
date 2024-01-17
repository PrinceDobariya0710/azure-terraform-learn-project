add-content -path c:/Users/bbdnet10187/.ssh/config - value @'

Host ${hostname}
    HostName ${hostname}
    USer ${user}
    IdentityFile ${Identityfile}
'@