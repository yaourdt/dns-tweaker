#!/bin/bash

dns_server="9.9.9.9"
interface="Wi-Fi"
log_file=/dev/null

######################################

install_dir=$HOME/.dns-tweaker
lock_file=$install_dir/dns-tweaker.lock
#log_file=$install_dir/dns-tweaker.log

# turn on trusted DNS server if not already active
trusted_dns_on() {
    current_dns=$(echo "show State:/Network/Global/DNS" | scutil | grep -o '0 : [^$]*' | awk '{print $3}')

    if [[ "$dns_server" != "$current_dns" ]]; then
        networksetup -setdnsservers $interface $dns_server
        echo `date` - ON: changed current DNS from $current_dns to $dns_server >> $log_file
        # changing the DNS server changes resolv.conf which in turn triggers this script which might change the DNS server -> lock file to avoid getting stuck in a loop
        touch $lock_file
    fi

    return 0
}

# turn off trusted DNS server and switch to local network default
trusted_dns_off() {
    current_dns=$(echo "show State:/Network/Global/DNS" | scutil | grep -o '0 : [^$]*' | awk '{print $3}')
    networksetup -setdnsservers $interface "Empty"
    local_dns=$(echo "show State:/Network/Global/DNS" | scutil | grep -o '0 : [^$]*' | awk '{print $3}')

    if [[ "$local_dns" != "$current_dns" ]]; then
        touch $lock_file 
        echo `date` - OFF: changed current DNS from $current_dns to $local_dns >> $log_file
    fi

    return 0
}

# ask MacOS if the interface is active. MacOS will return 'TRUE' or 'FALSE'
determine_link_up() {
    echo "show State:/Network/Interface/en0/Link" | scutil | grep -o 'Active : [^$]*' | awk '{print $3}'
    return 0
}

######################################

# does location for lock-file etc exist?
if [ ! -d "$install_dir" ]; then
    echo "$install_dir does not exist."
    exit 1
fi

# determine if this is an echo. If so, remove lock and exit
if [[ -f "$lock_file" ]]; then
    rm $lock_file
    exit 0
fi

# check if interface is active. If not, there is nothing to do
if [[ $(determine_link_up) == "FALSE" ]]; then
    exit 0
fi

# determine if we are online (use an external server, as stage tracking in MacOS frequently fails). 
# If online, enable trusted DNS (if not already done), else switch to local DNS
response_body=$(curl -s captive.apple.com)
response_code=$?
if [[ $response_code == 0 ]]; then
    if [[ $response_body == "<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>" ]]; then
        trusted_dns_on
    else
        trusted_dns_off
    fi
else
    trusted_dns_off
fi

exit 0
