#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Custom script for installing the kubernetes cluster

main() {
    # Determine if the current environment is WSL
    if grep -qi microsoft /proc/version; then
        IS_WSL=1
    fi

    test_is_admin;
    get_local_fqdn;

    # Download latest ISO
    download_iso;
    download_butane;
    modify_iso;
    upload_iso;

    deploy_Sagittarius;
    # deploy_Messier;
    # deploy_Bouvard;
    # deploy_LeVerrier;
}

test_is_admin() {
    # Test if we are running as administrator (needed for port_forwarding)
    if [ $IS_WSL ]; then
        net.exe session &> /dev/null
        if [ $? -ne 0 ]; then
            logFatal "You must run this console with elevated administrative privileges"
        fi
    fi
}

deploy_Sagittarius() {
    local host=Sagittarius
    local host_bindir="$ROOT/build/${host}"
    export LOCAL_CONFIG=".config/demers.config:.config/local.config"

    mkdir -p "$host_bindir"
    pushd "$host_bindir" > /dev/null

    # Generate Butane for this node
    cat $IGNITION_IN | sed -e "s/<hostname>/${host}/" \
    -e "s/<ssh_key>/${SSH_KEY}/" > custom.bu

    # Convert to ignition file
    $BUTANE -o "custom.ig" "custom.bu"
    if [[ $? -ne 0 ]]; then
        logFatal "Failed to convert into ignition: custom.ig"
    else
        logInfo "Ignition generated: custom.ig"
    fi

    start_server;

    $DEPLOY_EXEC vm ${host} -c=1 -d=10GiB -r=4GiB --iso="${ISO_CUSTOM}"

    # Try SSH. Abort in 20 minutes (OS install might take a while)
    logInfo "Checking if the new VM is online"
    local timeout_min=20
    local abort_by=$(( $(date +%s) + $(( $timeout_min * 60 )) ))
    local expected_hostname=$(echo $FQDN | sed -e "s/${HOSTNAME}/${host}/")
    local cmd="ssh -oStrictHostKeyChecking=no core@${expected_hostname} 'exit'"
    $(eval ${cmd})
    local err=$?
    while [[ $err -gt 0 ]]; do
        if [[ $(date +%s) -ge $abort_by ]]; then
            logError "Waited for ${timeout_min} minutes. Still getting an error ($err)"
            break
        fi
        sleep 5 # Don't DDOS the new VM
        logTrace "Waiting for ${host} to be online via SSH ($err)"
        $(eval ${cmd})
        err=$?
    done

    logTrace "Done waiting for VM to come online"
    stop_server;

    if [[ "$err" -ne 0 ]]; then
        logFata "VM ${host} never came online"
    else
        $DEPLOY_EXEC eject-iso ${host}
        if [[ $? -ne 0 ]]; then
            logFatal "Failed to eject ISO"
        else
            logInfo "Ejected ISO successfully"
    fi
    fi

    popd > /dev/null
}

deploy_Messier() {
    local host=Messier
    local host_bindir="$ROOT/build/${host}"
    export LOCAL_CONFIG=".config/sonia.config:.config/local.config"

    export LOCAL_CONFIG=".config/sonia.config:.config/local.config"
    $DEPLOY_EXEC vm ${host} -c=1 -d=10GiB -r=4GiB --iso="${ISO_CUSTOM}"
}

deploy_Bouvard() {
    
    local host=Sagittarius
    local host_bindir="$ROOT/build/${host}"
    export LOCAL_CONFIG=".config/demers.config:.config/local.config"
    
    $DEPLOY_EXEC vm ${host} -c=8 -d=128GiB -r=32GiB --iso="${ISO_CUSTOM}"
}

deploy_LeVerrier() {
    local host=Sagittarius
    local host_bindir="$ROOT/build/${host}"
    export LOCAL_CONFIG=".config/sonia.config:.config/local.config"

    $DEPLOY_EXEC vm ${host} -c=8 -d=128GiB -r=32GiB --iso="${ISO_CUSTOM}"
}

start_server() {
    logInfo "Start HTTPS server on port $SERVER_PORT"

    # Start webserver for Fedora CoreOS ignition
    SERVER_PID=""
    (&>/dev/null python "$SERVER_EXEC" &)
    if [ $? -ne 0 ]; then
        logFatal "Cannot launch HTTPS server"
    else
        SERVER_PID=$(pgrep 'python')
        if [ -z $SERVER_PID ]; then
            logFatal "Failed to start HTTPS server"
        else
            logTrace "Started HTTPS server: $SERVER_PID"
        fi
    fi

    # Start WSL port forwarding
    if [ $IS_WSL ]; then
        FORWARD_PID=""
        (&>/dev/null port_forwarding &)
        if [ $? -ne 0 ]; then
            pkill -9 -f python
            logFatal "Could not launch WSL port_forwarding"
        else
            FORWARD_PID=$(pgrep 'port_forwarding')
            if [ -z $FORWARD_PID ]; then
                pkill -9 -f http.server
                logFatal "Failed to start port forwarder"
            else
                logTrace "Started forwarder: $FORWARD_PID"
            fi
        fi
    fi
}

stop_server() {
    logInfo "Killing HTTP server..."

    kill -s SIGTERM $SERVER_PID

    if [ $IS_WSL ]; then
        kill -s SIGTERM $FORWARD_PID
    fi

    logInfo "Killed!"
}

get_local_fqdn() {
    if [ $IS_WSL ]; then

        # Find hostname
        HOSTNAME=$(wsl.exe hostname -s)
        if [ -z "$HOSTNAME" ]; then
            logFatal "Could not determine hostname"
        else
            HOSTNAME=$(echo $HOSTNAME | xargs)
            HOSTNAME=${HOSTNAME%$'\r'}
            logTrace "Hostname: $HOSTNAME"
        fi

        # Find Host's IP address
        local ip_regex=".*Pinging $HOSTNAME\\..*\\[(.*)\\].*"
        local ping_res=$(ping.exe -n 1 -4 $HOSTNAME)
        if [[ "$ping_res" =~ $ip_regex ]]; then
            local ip=$(echo ${BASH_REMATCH[1]} | xargs)
            ip=${ip%$'\r'}
            logTrace "IP: $ip"
        else
            logFatal "Did not find IP in: ${ping_res}\nUsing regex: ${ip_regex}"
        fi

        # Find Host's default gateway (assuming it is the DNS server)
        local gw_res=$(WMIC.exe NICConfig where IPEnabled="True" get DefaultIPGateway /value)
        local gw_regex='.*DefaultIPGateway=\{\"(.*)\",.*'
        if [[ "$gw_res" =~ $gw_regex ]]; then
            local gw=$(echo ${BASH_REMATCH[1]} | xargs)
            gw=${gw%$'\r'}
            logTrace "Gateway: $gw"
        else
            logFatal "Did not find Gateway in: ${gw_res}"
        fi

        # Find FQDN as seen by the Gateway
        local fqdn_res=$(nslookup.exe $ip $gw)
        local fqdn_regex='.*Name:\s*(.*)\s+Address.*'
        if [[ "$fqdn_res" =~ $fqdn_regex ]]; then
            FQDN=$(echo ${BASH_REMATCH[1]} | xargs)
            FQDN=${FQDN%$'\r'}
            logTrace "FQDN: $FQDN"
        else
            logFatal "Did not find FQDN in: ${fqdn_res}"
        fi
    else
        logFatal "Unsupported get_local_fqdn"
    fi
}

download_iso() {
    logInfo "Download ISO using coreos-installer"

    local cmd="$COREOS_EXEC download -f iso -C $COREOS_BINDIR"
    mkdir -p "$COREOS_BINDIR"

    execute "$cmd"
    if [[ $? -ne 0 ]]; then
        logFatal "Failed to download ISO"
    else
        # Extract name of iso from output
        ISO_PATH=$(echo $RES | grep ".iso" | xargs)
        ISO_NAME=$(basename $ISO_PATH)
		logInfo "ISO downloaded: $ISO_NAME"
	fi
}

upload_iso() {
    local iso_to_upload=$(dirname $ISO_PATH)/${ISO_CUSTOM}

    export LOCAL_CONFIG=".config/sonia.config:.config/local.config"
    $DEPLOY_EXEC upload-iso "$iso_to_upload"

    export LOCAL_CONFIG=".config/demers.config:.config/local.config"
    $DEPLOY_EXEC upload-iso "$iso_to_upload"
}

download_butane() {
    pushd $COREOS_BINDIR > /dev/null
    
    local base=$(basename $BUTANE_URL)
    BUTANE="$(pwd)/${base}"

    echo "Make sure we have butane locally: ${base}"
    if [ -f $base ]; then
        logInfo "Butane is already downloaded"
        popd > /dev/null
        return 0
    fi

    curl -LO $BUTANE_URL --output $base
    if [[ $? -ne 0 ]]; then
        logFatal "Failed to download butane from: $BUTANE_URL"
    else
        chmod +x $base
        logInfo "Butane downloaded to: $BUTANE"
    fi

    popd > /dev/null
}

modify_iso() {
    # Filenames
    local ignition_file="remote-ignition.ig"
    local butane_file=$(echo $ignition_file | sed -e 's/\.ig/.bu/')
    ISO_CUSTOM=$(echo $ISO_NAME | sed -e "s/\\.iso/_${HOSTNAME}.iso/")

    # Don't generate custom ISO if it already exists
    if [ -f "${COREOS_BINDIR}/${ISO_CUSTOM}" ]; then
        logInfo "Custom ISO already exists"
        return 0
    fi

    pushd $COREOS_BINDIR > /dev/null

    # Generate the Butane file we want to embedded in the ISO
cat > ${butane_file} <<- EOF
variant: fcos
version: 1.5.0
ignition:
  config:
    replace:
      source: "https://${FQDN}:${SERVER_PORT}/custom.ig"
  security:
    tls:
      certificate_authorities:
      - local: "$(basename $ROOT/$IG_CA)"
EOF

    # Convert to ignition file
    $BUTANE -o "${ignition_file}" -d "$(dirname $ROOT/$IG_CA)" ${butane_file}
    if [[ $? -ne 0 ]]; then
        logFatal "Failed to convert into ignition: $butane_file"
    else
        logInfo "Ignition generated: ${ignition_file}"
    fi

    # Modify ISO
    local cmd="$COREOS_EXEC iso customize --dest-device /dev/xvda --dest-ignition ${ignition_file} -o ${ISO_CUSTOM} $ISO_NAME"
    execute "$cmd"
    if [[ $? -ne 0 ]]; then
        logFatal "Failed to generate custom ISO: $ISO_CUSTOM"
    else
        logInfo "Custom ISO generated: ${ISO_CUSTOM}"
    fi

    popd > /dev/null
}

###########################
###### Startup logic ######
###########################

## Path configurations ##
ROOT="$(git rev-parse --show-toplevel)"

COREOS_BINDIR=$ROOT/build/coreos-iso
COREOS_EXEC=$(realpath ~/.cargo/bin/coreos-installer)

IGNITION_IN="$ROOT/data/custom.ig.in"
SERVER_EXEC="$ROOT/src/bootstrap/01-vm/ignition-server.py"
DEPLOY_EXEC="$ROOT/src/bootstrap/01-vm/deploy_vm.sh"
LOGGER_EXEC="$ROOT/tools/logger-shell/logger.sh"
SHUTILS_EXEC="$ROOT/tools/shell-utils/shell-utils.sh"


# Import logger
if [ -z "$LOGFILE" ]; then
  . "$LOGGER_EXEC"
fi

# Load configuration
CONFIGS=(.config/default.config)
CONFIGS+=(${LOCAL_CONFIG//:/ })
for config in ${CONFIGS[@]}; do
	log "Loading config: $config"
	source "$ROOT/${config}"
done

# Import shell utilities
. "$SHUTILS_EXEC"


log "== $ME Started =="
main;

log "== $ME Exited gracefully =="