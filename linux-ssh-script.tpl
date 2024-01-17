cat << EOF >> ~/.ssh/config

Host ${hostname}
    HostName ${hostname}
    USer ${user}
    IdentityFile ${Identityfile}
EOF