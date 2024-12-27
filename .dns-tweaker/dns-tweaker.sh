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

# ask MacOS if it detected a captive portal. MacOS will return 'Online', 'Unknown', 'Evaluate', 'Websheet' or ...?
determine_stage() {
    echo "show State:/Network/Interface/en0/CaptiveNetwork" | scutil | grep -o 'Stage : [^$]*' | awk '{print $3}'
    return 0
}

# ask MacOS if the interface is active. MacOS will return 'TRUE' or 'FALSE'
determine_link_up() {
    echo "show State:/Network/Interface/en0/Link" | scutil | grep -o 'Active : [^$]*' | awk '{print $3}'
    return 0
}

# ask MacOS if a detected captive portal is waiting for user input. MacOS will return 'FALSE' or ...?
determine_wait_on_user() {
    echo "show State:/Network/Interface/en0/CaptiveNetwork" | scutil | grep -o 'WaitingOnUI : [^$]*' | awk '{print $3}'
    return 0
}

######################################

# does location for lock-file etc exist?
if [ ! -d "$install_dir" ]; then
    echo "$install_dir does not exist."
    exit 0
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

# determine if we are online. If so enable trusted DNS (if not already done) and exit
if [[ $(determine_stage) == "Online" ]]; then
    trusted_dns_on
    exit 0
fi

# it is uncertain, whether we are online. We might need to use local DNS until we have a clear state
trusted_dns_off

# wait up to 30 seconds for the stage to settle
timeout=30
while [[ $timeout != 0 ]]; do
    if [[ $(determine_stage) =~ ^(Evaluate|Unknown)$ ]]; then
        sleep 1
        timeout=$((timeout - 1))
    else
        break
    fi
done

# wait up to 5 minutes for the user to solve a captive portal
timeout=300
while [[ $timeout != 0 ]]; do
    if [[ $(determine_wait_on_user) == "TRUE" ]]; then
        sleep 1
        timeout=$((timeout - 1))
    else
        break
    fi
done

# determine (again) if we are online. If so enable trusted DNS (if not already done) and exit
if [[ $(determine_stage) == "Online" ]]; then
    trusted_dns_on
    exit 0
fi

# determine (again) if we are online, but use an external server, as stage tracking in MacOS sometimes fails. If so enable trusted DNS (if not already done) and exit
response_body=$(curl -s captive.apple.com)
response_code=$?
if [[ $response_code == 0 ]]; then
    if [[ $response_body == "<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>" ]]; then
        trusted_dns_on
        exit 0
    fi
fi

# we have reached the end of our script and should not be here. Print some debug info and exit
echo `date` - I was not able to determine whether there is a captive portal. Stage: $(determine_stage) - waitOnUser: $(determine_wait_on_user) >> $log_file
exit 1

