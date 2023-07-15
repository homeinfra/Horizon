#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# This script is used to setup the local environement used to remotely deploy
# the infrastructure described by this git repository.
# In other words, this should only be run once on a client computer.
# 
# Currently only supports Ubuntu WSL (Windows Subsystem for Linux)


main() {
    parse;

    # Make sure that XE is available locally
    xe_init;

	# Update package repositories
	sudo apt-get update

	# Dependencies for bootstraping Fedora Core OS
	sudo apt-get install -y smbclient python3-pip cargo pkg-config libssl-dev libzstd-dev sshpass
	if [[ $? -ne 0 ]]; then
        logFatal "Failed to apt-get"
    else
		logTrace "apt-get succeeded"
	fi

	# Further dependencies for FCOS
	install_wsl_port_forwarding;
	install_coreos_installer;
	install_ansible;

	# Encryption dependencies
	install_sops;
	install_age;
	config_key;
}

config_key() {
	# Configure a new encryption key if you don't already have one
	local key_loc="$HOME/.sops/key.txt"
	if [ ! -f "$key_loc" ]; then
		echo "###########################################################"
		echo "###### No encryption key found. Generating a new one ######"
		echo "###########################################################"

		age-keygen -o "$key_loc"
		if [[ $? -ne 0 ]]; then
			logFatal "Failed to generate a new encryption key"
		else
			logTrace "Key generation succeeded"
		fi
	else
		logTrace "Key already exists"
	fi

	add_env "SOPS_AGE_KEY_FILE" "\"$key_loc\""
}

install_age() {
	# Check if already installed
	age --version
    if [[ $? -ne 0 ]]; then
		logTrace "Installing age..."
		mkdir -p $ROOT/build
		pushd $ROOT/build

		local dl=$(basename $AGE_URL)
		local dir=$(basename $AGE_URL .tar.gz)
		curl -LO $AGE_URL --output $dl
		if [[ $? -ne 0 ]]; then
			logFatal "Failed to download SOPS"
		else
			logTrace "SOPS download succeeded"
		fi

		mkdir -p $dir
		tar -xvf $dl -C $dir
		if [[ $? -ne 0 ]]; then
			logFatal "Failed to extract age"
		fi

		pushd $dir/age
		cp $AGE_FILES ~/bin/
		chmod +x $AGE_FILES
		popd

		rm -r $dir
		rm $dl
		popd
    else
		logInfo "age already installed"
	fi
}

install_sops() {
	# Check if already installed
	sops -v
    if [[ $? -ne 0 ]]; then
		mkdir -p $ROOT/build
		pushd $ROOT/build

        logTrace "Installing SOPS..."
		local installer=$(basename $SOPS_URL)
		curl -LO $SOPS_URL --output $installer
		if [[ $? -ne 0 ]]; then
			logFatal "Failed to download SOPS"
		else
			logTrace "SOPS download succeeded"
		fi

		sudo apt-get install -y ./$installer
		if [[ $? -ne 0 ]]; then
			logFatal "Failed to install SOPS"
		else
			logTrace "SOPS install succeeded"
		fi

		rm -r $installer

		mkdir -p ~/.sops

		popd
    else
		logInfo "SOPS already installed"
	fi
}

install_ansible() {
	local install=ansible
	local exec=ansible

	# Check if available
	local is_installed=1
	local res=$(which $exec)
	if [ $? -ne 0 ]; then
        is_installed=0
	elif [ -z $res ]; then
		is_installed=0
	else
		res=${res%$'\r'}
		logTrace "Found $exec here: $res"
    fi

	if [[ $is_installed -eq 0 ]]; then
		logInfo "Installing $exec"
		sudo pip install $install
	else
		logTrace "$exec is already installed"
	fi

	# Try it, to see if it's installed
	$exec --version
	if [[ $? -ne 0 ]]; then
        logFatal "Failed to launch $exec"
    else
		logTrace "$exec started"
	fi

	pkill -9 -f $exec
	logInfo "$exec tested successfully"
}

# We are hidden behind WSL bridging. We require Windows to forward open ports back to WSL
# This tool achieves this by monitoring all open ports on WSL and adding forwarding info on windows side
# This requires windows elevated administrator privilege. Make sure you run a WSL terminal as admin.
install_wsl_port_forwarding() {

	local install=wsl_port_forwarding
	local exec=port_forwarding

	# Check if available
	local is_installed=1
	local res=$(which $exec)
	if [ $? -ne 0 ]; then
        is_installed=0
	elif [ -z $res ]; then
		is_installed=0
	else
		res=${res%$'\r'}
		logTrace "Found $exec here: $res"
    fi

	if [[ $is_installed -eq 0 ]]; then
		logInfo "Installing $exec"
		sudo pip install $install
	else
		logTrace "$exec is already installed"
	fi

	# Try it, to see if it's installed
	$exec -h >> /dev/null
	if [[ $? -ne 0 ]]; then
        logFatal "Failed to launch $exec"
    else
		logTrace "$exec started"
	fi

	pkill -9 -f $exec
	logInfo "$exec tested successfully"
}

install_coreos_installer() {
	
	pushd ~ > /dev/null
	$COREOS_EXEC -V
    if [[ $? -ne 0 ]]; then
        logTrace "Installing coreos-installer from source..."
		cargo install coreos-installer
		if [[ $? -ne 0 ]]; then
			logFatal "Failed to cargo install"
		else
			logTrace "cargo install succeeded"
		fi
    else
		logInfo "coreos-installer already installed"
	fi
    popd > /dev/null
}

uninstall() {
	cargo uninstall coreos-installer
	sudo pip uninstall -y wsl_port_forwarding ansible
	sudo apt-get purge -y smbclient python3-pip cargo pkg-config libssl-dev libzstd-dev sshpass sops
	sudo apt-get autoremove -y

	pushd ~/bin
	rm -f $AGE_FILES
	popd

}

parse() {
	if [ $NUM_ARGS -eq 0 ]; then
		: # It's OK
	else
		for i in "${ARGS[@]}"; do
			case $i in
				-h|--help)
					print_help;
					;;
				-v|--version)
					echo $($SEMVER_EXEC)
					;;
				-u|--uninstall)
				uninstall;
				;;
				*)
					print_help;
					logFatal "Unexpected arguments (${NUM_ARGS}): ${ARGS[*]}"
					;;
			esac		
		done
		end;
	fi
}

print_help() {
    echo "usage: $ME [-h|--help|-v|--version]"
    echo "  -h,--help       Print this usage message"
	echo "  -v,--version    Print the version of this tool"
	echo "  -u,--uninstall  Remove anything installed by this script"
}

end() {
    log "== $ME Exited gracefully =="

    # If we reach here, execution completed succesfully
    exit 0
}

###########################
###### Startup logic ######
###########################

# Keep a copy of entry arguments
NUM_ARGS="$#"
ARGS=("$@")

# Path Configuration
ROOT="$(git rev-parse --show-toplevel)"
COREOS_EXEC=$(realpath ~/.cargo/bin/coreos-installer)
LOGGER_EXEC="$ROOT/tools/logger-shell/logger.sh"
SEMVER_EXEC="$ROOT/tools/semver/semver.sh"
SHUTILS_EXEC="$ROOT/tools/shell-utils/shell-utils.sh"
XE_EXEC="$ROOT/libs/xapi-shell/xe.sh"
AGE_FILES="age age-keygen"

# Import logger
. "$LOGGER_EXEC"
log "== $ME Started =="

# Load configuration
CONFIGS=(.config/default.config)
CONFIGS+=(${LOCAL_CONFIG//:/ })
for config in ${CONFIGS[@]}; do
	log "Loading config: $config"
	source ${ROOT}/${config}
done

# Import xe library
. "$XE_EXEC"

# Import shell-utils
. "$SHUTILS_EXEC"

# Call main function
main;

# Exit gracefully
end;