#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Adds helper functions for the xe cli tool
# Import/source this script into your own

#####################################
###### API Variables ################
#####################################
# Below are the variables the library consumer is epxected to interact with

# In parameters (with default values)
VM_TEMPLATE="${VM_TEMPLATE:-""}" # If no template provided, ram, cpu and disk must be provided
VM_NAME="${VM_NAME:-""}"         # Name of the virtual machine
VM_NET="${VM_NET:-""}"           # Network the VM should be connected to (optional)
VM_ISO="${VM_ISO:-""}"           # ISO the VM should be mounted with (optional)
VM_RAM="${VM_RAM:-""}"           # Amount of RAM the VM should be mounted with (mandatory if no template)
VM_DISK="${VM_DISK:-""}"         # Disk size the VM should be mounted with (mandatory if no template)
VM_CPU="${VM_CPU:-""}"           # Number of CPUs the VM should be mounted with (mandatory if no template)
VM_SR="${VM_SR:-""}"             # Storage repository where this VM's disk should be created
VM_TAGS="${VM_TAGS:-""}"         # Tags to be added to the VM at creation. Exemple Tags: 	post_autostartup, pre_shutdown

# In/Out parameters (Filled up by this library, can be used by the calling code)
TEMPLATE_UUID=""    # Set after a call to: xe_find_tempalte
VM_UUID=""          # Set after a call to: xe_find_vm, xe_install_vm
VIF_UUID=""         # Set after a call to: xe_attach_network
ISO_UUID=""         # Set after a call to: xe_find_iso
SR_UUID=""          # Set after a call to: xe_find_sr
VDI_UUID=""         # Set after a call to: xe_find_disk, xe_create_disk

#####################################
###### PUBLIC API ###################
#####################################

# Make sure XE is available, working and that XCP-ng is reachable
# Before a call, the following must be set
#   - <none>
# After call, the following have been set:
#   - XE
#   - LOGIN
xe_init() {
  logDebug "Looking for XE"

  # Search specific paths on Windows Subsystem for Linux
  if [[ -d "/mnt/c/Program Files/XCP-ng Center" ]]; then
    logTrace "Found XE by looking directly into 'Program Files' from WSL"
    XE="/mnt/c/Program Files/XCP-ng Center/xe.exe"
  elif [[ -d "/mnt/c/Program Files (x86)/XCP-ng Center" ]]; then
    logTrace "Found XE by looking directly into 'Program Files (x86)' from WSL"
    XE="/mnt/c/Program Files (x86)/XCP-ng Center/xe.exe"
  # Search with Linux 'which'
  else
    logTrace "Found XE by calling 'which xe'"
    # shellcheck disable=2230
    XE=$(which xe)
  fi

  if [[ ! -f "${XE}" ]]; then
    logFatal "Could not find xen utilities (xe)"
  fi

  # shellcheck disable=2154
  LOGIN="-s ${XEN_HOST} -u ${XEM_USER} -pw ${XEN_PWD} -p ${XEN_PORT}"
  cmd="\"${XE}\" ${LOGIN} help"

  if ! eval "${cmd}" > /dev/null; then
    logFatal "XE is not working"
  fi

  logInfo "Found XE here: ${XE}"
}

# Find the template to use
# Before a call, the following must be set
#   - XE
#   - LOGIN
#   - VM_TEMPLATE
# After call, the following have been set:
#   - TEMPLATE_UUID
xe_find_template() {
  local RES=0
  local cmd="\"${XE}\" ${LOGIN} template-list name-label=\"${VM_TEMPLATE}\" params=uuid --minimal"
  # shellcheck disable=2312
  if ! RES=$(eval "${cmd}" | xargs); then
    logFatal "XE Failed to list templates"
  elif [[ -z "${RES}" ]]; then
    logFatal "Could not find VM template: ${VM_TEMPLATE}"
  else
    TEMPLATE_UUID=${RES%$'\r'}
    logTrace "Template UUID: ${TEMPLATE_UUID}"
  fi
}

# Find the ISO to use
# Before a call, the following must be set
#   - XE
#   - LOGIN
#   - VM_ISO
# After call, the following have been set:
#   - ISO_UUID
xe_find_iso() {
  ISO_UUID=""
  local RES=0
  local cmd="\"${XE}\" ${LOGIN} cd-list"
  # shellcheck disable=2312
  if ! RES=$(eval "${cmd}" | grep ': '); then
    logFatal "XE Failed to list CDs"
  elif [[ -n "${RES}" ]]; then
    # We will be returned multiple CDs. Loop through them
    local line_count=0
    local CUR_UUID=""
    local CUR_NAME=""
    while IFS= read -r line; do
      if [[ $((line_count % 2)) == 0 ]]; then
        CUR_UUID=$(echo "${line#*:}" | xargs)
      else
        CUR_NAME=$(echo "${line#*:}" | xargs)
        if [[ "${CUR_NAME}" == "${VM_ISO}" ]]; then
          ISO_UUID=${CUR_UUID%$'\r'}
          logInfo "Found ISO: ${CUR_UUID} (${CUR_NAME})"
          break
        else
          logTrace "Ignoring ISO: ${CUR_UUID} (${CUR_NAME})"
        fi

        CUR_UUID=""
        CUR_NAME=""
      fi

      line_count=$((line_count + 1))
    done <<< "${RES}"
  else
    logFatal "No CD available"
  fi

  if [[ -z "${ISO_UUID}" ]]; then
    logFatal "ISO \"${VM_ISO}\" not found!"
  fi
}

# Find the network to use
# Before a call, the following must be set
#   - XE
#   - LOGIN
#   - VM_NET
# After call, the following have been set:
#   - NET_UUID
xe_find_net() {
  # Find the network we need to attach
  local RES=0
  local cmd="\"${XE}\" ${LOGIN} network-list name-label=\"${VM_NET}\" params=uuid --minimal"
  # shellcheck disable=2312
  if ! RES=$(eval "${cmd}" | xargs); then
    logFatal "XE Failed to list networks"
  elif [[ -z "${RES}" ]]; then
    logFatal "No networks found named: ${VM_NET}"
  else
    NET_UUID=${RES%$'\r'}
    logTrace "Network UUID: ${NET_UUID}"
  fi
}

# Find the VM by name
# Before a call, the following must be set
#   - XE
#   - LOGIN
#   - VM_NAME
# After call, the following have been set if found, empty if not:
#   - VM_UUID
xe_find_vm() {
  local RES=0
  local cmd="\"${XE}\" ${LOGIN} vm-list name-label=\"${VM_NAME}\" params=uuid --minimal"
  # shellcheck disable=2312
  if ! RES=$(eval "${cmd}" | xargs); then
    logFatal "XE Failed to list VMs"
  elif [[ -z "${RES}" ]]; then
    VM_UUID=""
    logError "VM ${VM_NAME} does not exists"
  else
    VM_UUID=${RES%$'\r'}
    logInfo "VM ${VM_NAME} exists: ${VM_UUID}"
  fi
}

# Find the Storage Repository by name
# Before a call, the following must be set
#   - XE
#   - LOGIN
#   - VM_SR
# After call, the following have been set if found, empty if not:
#   - SR_UUID
xe_find_sr() {
  local RES=0
  local cmd="\"${XE}\" ${LOGIN} sr-list name-label=\"${VM_SR}\" params=uuid --minimal"
  # shellcheck disable=2312
  if ! RES=$(eval "${cmd}" | xargs); then
    logFatal "XE Failed to list storage repositories"
  elif [[ -z "${RES}" ]]; then
    logFatal "Could not find SR: ${VM_SR} ${RES}"
  else
    SR_UUID=${RES%$'\r'}
    logTrace "SR UUID: ${SR_UUID}"
  fi
}

# Create a VM using the parameters described below
# Before a call, the following must be set
#   - XE
#   - LOGIN
#   - VM_NAME
#   - SR_UUID
#   - TEMPLATE_UUID (optional)
# After call, the following have been set:
#   - VM_UUID
xe_install_vm() {
  local cmd="\"${XE}\" ${LOGIN} vm-install new-name-label=\"${VM_NAME}\" sr-uuid=\"${SR_UUID}\" --minimal"
  if [[ -z "${TEMPLATE_UUID}" ]]; then
    VM_TEMPLATE="Other install media"
    xe_find_template
    cmd="${cmd} template-uuid=${TEMPLATE_UUID}"
    VM_TEMPLATE=""
    TEMPLATE_UUID=""
  else
    cmd="${cmd} template-uuid=${TEMPLATE_UUID}"
  fi

  local RES=0
  # shellcheck disable=2312
  if ! RES=$(eval "${cmd}" | xargs); then
    logFatal "XE Failed to create VM using template: ${VM_TEMPLATE} on SR: ${VM_SR}"
  elif [[ -z "${RES}" ]]; then
    logFatal "Empty response. Did we fail to create VM?"
  else
    VM_UUID=${RES%$'\r'}
    logInfo "VM ${VM_NAME} created: ${VM_UUID}"
  fi

  xe_rename_new_disks
  xe_create_disk
  xe_add_tags
}

# Compares the current disk size with the desired one, and correct if necessary
# Before a call, the following must be set
#   - XE
#   - LOGIN
#   - VM_DISK
#   - VDI_UUID
#   - TEMPLATE_UUID (optional)
# After call, the following have been set:
#   - <none>
xe_adjust_disk_size() {
  xe_find_disk

  # If we are expecting a specified disk
  if [[ -n "${VM_DISK}" ]]; then

    # If we are expecting a disk and it doesn't exist? Create it
    if [[ -z "${VDI_UUID}" ]]; then
      xe_create_disk
      xe_find_disk
    fi

    # Get disk size
    local RES=0
    local cmd="\"${XE}\" ${LOGIN} vdi-param-get uuid=\"${VDI_UUID}\" param-name=virtual-size --minimal"
    # shellcheck disable=2312
    if ! RES=$(eval "${cmd}" | xargs); then
      logFatal "XE Failed to get disk size of ${VDI_UUID}"
    elif [[ -z "${RES}" ]]; then
      logFatal "Empty response. Did we fail to get disk size?"
    else
      local size=${RES%$'\r'}
      size=$((size / 1024 / 1024))
      logInfo "Disk current size=${size}MiB. Desired size: ${VM_DISK}MiB"
      if [[ ${size} -ne "${VM_DISK}" ]]; then
        logInfo "Size missmatch, attempting to change size"
        xe_vm_shutdown
        cmd="\"${XE}\" ${LOGIN} vdi-resize uuid=\"${VDI_UUID}\" disk-size=\"${VM_DISK}MiB\" --minimal"
        if ! RES=$(eval "${cmd}" | xargs); then
          logFatal "XE Failed to resize disk ${VDI_UUID}"
        elif [[ -n "${RES}" ]]; then
          logFatal "Non-Empty response. Did we fail to resize disk? (${RES})"
        else
          logInfo "Disk resise was successful"
        fi

      else
        logTrace "Size Ok!"
      fi
    fi
  fi
}

# Graceful shutdown of the VM if running
# Before a call, the following must be set
#   - XE
#   - LOGIN
#   - VM_UUID
# After call, the following have been set:
#   - <none>
xe_vm_shutdown() {
  xe_get_vm_param "power-state"
  local cur_state=${PARAM}

  # If not halted, send command to shutdown
  if [[ "${cur_state}" != "halted" ]]; then
    local RES=0
    local cmd="\"${XE}\" ${LOGIN} vm-shutdown uuid=\"${VM_UUID}\" --minimal"
    # shellcheck disable=2312
    if ! RES=$(eval "${cmd}" | xargs); then
      logFatal "XE Failed to shutdown ${VM_UUID}"
    elif [[ -n "${RES}" ]]; then
      logFatal "Non-Empty response. Did we fail to shutdown state? (${RES})"
    else
      logInfo "Shutdown command sent successfully"
    fi

    # Wait until shutdown is complete
    while [[ "${cur_state}" != "halted" ]]; do
      sleep 1

      xe_get_vm_param "power-state"
      local cur_state=${PARAM}
    done
  fi
}

# Graceful shutdown of the VM if running
# Before a call, the following must be set
#   - XE
#   - LOGIN
#   - VM_UUID
#   - VM_CPU
# After call, the following have been set:
#   - <none>
# I'm getting a "Missing paremter" for 'platform:cores-per-socket'. Do not suport Dual and Quad cores for now
xe_adjust_cpu_count() {
  if [[ -n "${VM_CPU}" ]]; then
    # local cores_per_socket=1

    # # Try to have a more sensible core distribution by using dual and quad core CPUs
    # if [[ $((VM_CPU % 4)) -eq 0 ]] && [[ $VM_CPU -ge 8 ]]; then
    #   cores_per_socket=4
    # elif [[ $((VM_CPU % 2)) -eq 0 ]] && [[ $VM_CPU -ge 4 ]]; then
    #   # We have an off umber of CPUs, so let's have 2 cores per sockets
    #   cores_per_socket=2
    # fi

    # Get current config
    xe_get_vm_param "VCPUs-max"
    local cur_vcpus=${PARAM}

    # xe_get_vm_param 'platform:cores-per-socket';
    # local cur_cores_per_socket=$PARAM

    # Do we need to reconfigure?
    # if [[ $cur_vcpus -eq $VM_CPU ]] && [[ $cur_cores_per_socket -eq $cores_per_socket ]]; then
    if [[ ${cur_vcpus} -eq ${VM_CPU} ]]; then
      logInfo "CPUs already properly configued"
    else
      xe_vm_shutdown

      # xe_set_vm_param 'platform:cores-per-socket' '1';
      xe_set_vm_param "VCPUs-max" "${VM_CPU}"
      # xe_set_vm_param 'platform:cores-per-socket' "$cores_per_socket";
    fi
  fi
}

# Compares configured amount of RAM vs desired, and correct if necessary
#   - XE
#   - LOGIN
#   - VM_UUID
#   - VM_RAM
# After call, the following have been set:
#   - <none>
xe_adjust_ram_size() {
  if [[ -n "${VM_RAM}" ]]; then

    # Get current config
    xe_get_vm_param "memory-dynamic-min"
    local ram_min=$((PARAM / 1024 / 1024))
    xe_get_vm_param "memory-dynamic-max"
    local ram_max=$((PARAM / 1024 / 1024))

    logInfo "Current memory config: ${ram_min}MiB-${ram_max}MiB. Expecting: ${VM_RAM}MiB"
    if [[ ${VM_RAM} -ne ${ram_min} ]] || [[ ${VM_RAM} -ne ${ram_max} ]]; then
      logInfo "Memory missmatch. Correcting..."
      local RES=0
      local cmd="\"${XE}\" ${LOGIN} vm-memory-set memory=\"${VM_RAM}MiB\" uuid=\"${VM_UUID}\" --minimal"
      # shellcheck disable=2312
      if ! RES=$(eval "${cmd}" | xargs); then
        logFatal "XE Failed to set memory configuration on ${VM_NAME}"
      elif [[ -n "${RES}" ]]; then
        logFatal "Non-empty response. Did we fail to configure memory? (${RES})"
      fi
    else
      logInfo "Memory already configured"
    fi
  fi
}

# Compares configured ISO loaded with vs desired, and correct if necessary
#   - XE
#   - LOGIN
#   - VM_UUID
#   - ISO_UUID
# After call, the following have been set:
#   - <none>
xe_attach_iso() {
  # If we are expecting to find an attached ISO
  if [[ -n "${VM_ISO}" ]]; then
    local CUR_UUID=""

    # Check if the VM already got a CD attach
    local RES=0
    local cmd="\"${XE}\" ${LOGIN} vm-cd-list uuid=\"${VM_UUID}\" vbd-params=none vdi-params=uuid --multiple --minimal"
    # shellcheck disable=2312
    if ! RES=$(eval "${cmd}" | xargs); then
      logFatal "XE Failed to list CDs attached to ${VM_NAME}"
    elif [[ -n "${RES}" ]]; then
      # We could be returned multiple CDs. Loop through them
      RES=${RES%$'\r'}
      for i in ${RES//,/ }; do
        CUR_UUID=$(echo "${i%$'\r'}" | xargs)
        if [[ -z "${CUR_UUID}" ]]; then
          logFatal "We should not find an empty CD"
        elif [[ "${CUR_UUID}" == "${ISO_UUID}" ]]; then
          logInfo "${VM_NAME%$'\r'} is already attached to ${ISO_UUID%$'\r'}: ${VM_ISO%$'\r'}"
          break
        else
          logTrace "Not the VID we are looking for: ${CUR_UUID}"
        fi
        CUR_UUID=""
      done

      # Here, we need to eject first, since there's already a CD attached but it's the wrong one
      if [[ -z "${CUR_UUID}" ]]; then
        cmd="\"${XE}\" ${LOGIN} vm-cd-eject uuid=\"${VM_UUID}\" --minimal"
        if ! RES=$(eval "${cmd}" | xargs); then
          logFatal "XE Failed to eject the CD attached to ${VM_NAME}"
        elif [[ -n "${RES}" ]]; then
          logFatal "We shouldn't get a reponse to this: ${RES}"
        else
          logInfo "We succesfully ejected the current CD on ${VM_NAME}"
        fi
      fi
    else
      logInfo "No CDs attached to ${VM_NAME}"
    fi

    # Not already attached? Do it
    if [[ -z "${CUR_UUID}" ]]; then
      cmd="\"${XE}\" ${LOGIN} vm-cd-insert cd-name=\"${VM_ISO}\" uuid=\"${VM_UUID}\" --minimal"
      # shellcheck disable=2312
      if ! RES=$(eval "${cmd}" | xargs); then
        logFatal "XE Failed to insert the CD in ${VM_NAME}"
      elif [[ -n "${RES}" ]]; then
        # This should mean we have no drive at all on this VM, on which to insert a CD

        xe_find_vbd_device_id

        # Add a new CD drive
        cmd="\"${XE}\" ${LOGIN} vm-cd-add cd-name=\"${VM_ISO}\" device=\"${DEV_ID}\" uuid=\"${VM_UUID}\" --minimal"
        if ! RES=$(eval "${cmd}" | xargs); then
          logFatal "XE Failed to add a CD drive to ${VM_NAME}"
        elif [[ -n "${RES}" ]]; then
          logFatal "We shouldn't get a reponse to this: ${RES}"
        else
          logInfo "We successfully added a new drive and mounted the CD on ${VM_NAME}"
        fi
      else
        logInfo "We succesfully inserted the CD on ${VM_NAME}"
      fi
    fi
  fi
}

# EJect the ISO from the virtual optical disc drive
#   - XE
#   - LOGIN
#   - VM_NAME
# After call, the following have been set:
#   - <none>
xe_eject() {
  xe_find_vm

  if [[ -z "${VM_UUID}" ]]; then
    logFatal "VM ${VM_NAME} does not exist"
  fi

  local RES=0
  local cmd="\"${XE}\" ${LOGIN} vm-cd-eject uuid=\"${VM_UUID}\" --minimal"
  # shellcheck disable=2312
  if ! RES=$(eval "${cmd}" | xargs); then
    logFatal "XE Failed to eject the CD attached to ${VM_NAME}"
  elif [[ -n "${RES}" ]]; then
    logFatal "We shouldn't get a reponse to this: ${RES}"
  else
    logInfo "We succesfully ejected the current CD on ${VM_NAME}"
  fi
}

# Check if the desired network is connected to the VM, or add a VIF otherwise
#   - XE
#   - LOGIN
#   - VM_UUID
#   - NET_UUID
# After call, the following have been set:
#   - VIF_UUID
xe_attach_network() {
  # Are we expecting a network to be attached
  if [[ -n "${VM_NET}" ]]; then
    # Check if network is already attached
    VIF_UUID=""
    local RES=0
    local cmd="\"${XE}\" ${LOGIN} vm-vif-list uuid=\"${VM_UUID}\" params=uuid --minimal"
    # shellcheck disable=2312
    if ! RES=$(eval "${cmd}" | xargs); then
      logFatal "XE Failed to list networks"
    elif [[ -n "${RES}" ]]; then
      RES=${RES%$'\r'}
      logTrace "IF List: ${RES}"
      # We could be returned multiple interface. Loop through them
      for i in ${RES//,/ }; do
        local RES2=0
        cmd="\"${XE}\" ${LOGIN} vif-list uuid=\"${i}\" params=network-uuid --minimal"
        if ! RES2=$(eval "${cmd}" | xargs); then
          logFatal "XE Failed to list VIFs"
        elif [[ -z "${RES2%$'\r'}" ]]; then
          logFatal "We should not find a VIF with no networks"
        elif [[ "${RES2%$'\r'}" == "${NET_UUID}" ]]; then
          VIF_UUID=$(echo "${i}" | xargs)
          logInfo "${VM_NAME} is already attached to ${VM_NET}: ${VIF_UUID}"
          break
        else
          logTrace "Not the VIF we are looking for: ${i}"
        fi
      done
    else
      logInfo "No VIF attached to ${VM_NAME}"
    fi

    # if the VIF doesn't exist, create it
    if [[ -z "${VIF_UUID}" ]]; then
      # We need a VIF number
      xe_find_vif_device_id

      # Create the VIF
      cmd="\"${XE}\" ${LOGIN} vif-create vm-uuid=\"${VM_UUID}\" device=\"${DEV_ID}\" network-uuid=\"${NET_UUID}\" mac=random --minimal"
      # shellcheck disable=2312
      if ! RES=$(eval "${cmd}" | xargs); then
        logFatal "XE Failed to attach VIF"
      elif [[ -z "${RES}" ]]; then
        logFatal "Why did we not get a VIF_UUID?"
      else
        VIF_UUID=${RES%$'\r'}
        logTrace "VIF Attached: ${VIF_UUID}"
      fi
    fi
  fi
}

# Start the VM if not already running
# Before a call, the following must be set
#   - XE
#   - LOGIN
#   - VM_UUID
# After call, the following have been set:
#   - <none>
xe_start() {
  xe_get_vm_param "power-state"
  local cur_state=${PARAM}

  # If not running, send command to start
  if [[ "${cur_state}" != "running" ]]; then
    local RES=0
    local cmd="\"${XE}\" ${LOGIN} vm-start uuid=\"${VM_UUID}\" --minimal"
    # shellcheck disable=2312
    if ! RES=$(eval "${cmd}" | xargs); then
      logFatal "XE Failed to shutdown ${VM_UUID}"
    elif [[ -n "${RES}" ]]; then
      logFatal "Non-Empty response. Did we fail to shutdown state? (${RES})"
    else
      logInfo "Start command sent successfully"
    fi

    # Wait until start is complete
    while [[ "${cur_state}" != "running" ]]; do
      sleep 1

      xe_get_vm_param "power-state"
      local cur_state=${PARAM}
    done
  fi
}

# Find the primary HDD associated with this VM
#   - XE
#   - LOGIN
#   - VM_NAME
#   - VM_UUID
# After call, the following have been set if found, empty if not:
#   - VDI_UUID
xe_find_disk() {
  # Find the attached disk
  VDI_UUID=""
  local RES=0
  local cmd="\"${XE}\" ${LOGIN} vm-disk-list uuid=\"${VM_UUID}\" vdi-params=uuid,name-label vbd-params=none"
  # shellcheck disable=2312
  if ! RES=$(eval "${cmd}" | grep ': '); then
        logFatal "XE Failed to list disks"
  elif   [[ -n "${RES}" ]]; then
    RES=${RES%$'\r'}
    # We might be returned multiple disks. Loop through them
    local line_count=0
    local CUR_UUID=""
    local CUR_NAME=""
    while IFS= read -r line; do
      if [[ $((line_count % 2)) == 0 ]]; then
        CUR_UUID=$(echo "${line#*:}" | xargs)
      else
        CUR_NAME=$(echo "${line#*:}" | xargs)

        if [[ "${CUR_NAME}" == "${VM_NAME}_hdd" ]]; then
          VDI_UUID=${CUR_UUID%$'\r'}
          logInfo "Found disk: ${VDI_UUID} (${CUR_NAME})"
          break
        else
          logTrace "Ignoring disk: ${CUR_UUID} (${CUR_NAME})"
        fi

        CUR_UUID=""
        CUR_NAME=""
      fi

      line_count=$((line_count + 1))
    done <<< "${RES}"
  else
    logWarn "No disks present"
  fi
}

# Read a parameter of the VM
#   - XE
#   - LOGIN
#   - $1: Parameter to be read on the VM
# After call, the following have been set
#   - PARAM
xe_get_vm_param() {
  if [[ -z "$1" ]]; then
    logFatal "Missing get parameter: $1"
  fi

  logTrace "Getting parameter \"$1\" from: ${VM_NAME}"
  local RES=0
  local cmd="\"${XE}\" ${LOGIN} vm-param-get uuid=\"${VM_UUID}\" param-name=\"$1\" --minimal"
  # shellcheck disable=2312
  if ! RES=$(eval "${cmd}" | xargs); then
    logFatal "XE Failed to get parameter \"$1\" from VM: ${VM_NAME}"
  elif [[ -z "${RES%$'\r'}" ]]; then
    logError "Empty response. Did we fail to get parameter \"$1\" from VM: ${VM_NAME}?"
  else
    PARAM=${RES%$'\r'}
    logInfo "Parameter \"$1\" from ${VM_NAME} is: ${PARAM}"
  fi
}

# Writes a parameter of the VM
#   - XE
#   - LOGIN
#   - $1: Parameter to be set on the VM
#   - $2: Value for this parameter
# After call, the following have been set
#   - <none>
xe_set_vm_param() {
  if [[ -z "$1" ]] || [[ -z "$2" ]]; then
    logFatal "Missing parameter or value: $1=$2"
  fi

  logTrace "Setting parameter \"${1}\"=\"${2}\" to: ${VM_NAME}"
  local RES=0
  local cmd="\"${XE}\" ${LOGIN} vm-param-set uuid=\"${VM_UUID}\" \"$1\"=\"$2\" --minimal"
  # shellcheck disable=2312
  if ! RES=$(eval "${cmd}" | xargs); then
    logFatal "XE Failed to set parameter \"$1\" for VM: ${VM_NAME}"
  elif [[ -n "${RES%$'\r'}" ]]; then
    logFatal "Non-empty response. Did we fail to set parameter \"$1\" for VM: ${VM_NAME}? (${PARAM})"
  else
    PARAM=${RES%$'\r'}
    logInfo "Parameter \"$1\" for ${VM_NAME} is now: $2"
  fi
}

# Uploads a ISO to the library
#   - XE
#   - LOGIN
#   - XEN_ISO_LIB
#   - XEN_ISO_USER (optional, could be part of the LIB URI)
#   - XEN_ISO_PWD (optional, could be part of the LIB URI)
#   - $1: File to be uploaded
# After call, the following have been set if found, empty if not:
#   - return 0
xe_upload_file() {
  local uri_regex='^([a-z]+:\/\/)(([^:@\/]+)(:([^@\/]+)*)?@)?([^@:\/?]+)(:[0-9]+)?(\/[^?\s]*)?(\?[^\s]*)?$'

  # shellcheck disable=2154
  if [[ "${XEN_ISO_LIB%$'\r'}" =~ ${uri_regex} ]]; then
    local proto=${BASH_REMATCH[1]}
    local user=${BASH_REMATCH[3]}
    local pwd=${BASH_REMATCH[5]}
    local domain=${BASH_REMATCH[6]}
    local path=${BASH_REMATCH[8]}
    # local queryString=${BASH_REMATCH[9]}
    # local gp_count=0
    # for elem in ${BASH_REMATCH[@]}; do
    # 	gp_count=$(($gp_count + 1))
    # 	echo "${gp_count}: $elem"
    # done
  else
    logFatal "Unparsable URI: ${XEN_ISO_LIB}"
  fi

  local name=0
  name=$(basename "$1")
  if [[ -z "${user}" ]]; then
    # shellcheck disable=2154
    user=${XEN_ISO_USER}
  fi
  if [[ -z "${pwd}" ]]; then
    # shellcheck disable=2154
    pwd=${XEN_ISO_PWD}
  fi

  # Identify protocol being used
  case ${proto} in
    file://*) # UNC/SMB
      # We need to extract the first folder, and use it as share name
      local path_regex='^(\/[^\/\n?]+)(\/([^\n?]+))*(.*)$'
      if [[ "${path}" =~ ${path_regex} ]]; then
          local share=${BASH_REMATCH[1]}
        path=${BASH_REMATCH[3]}
      else
        logFatal "Unable to differentiate share and path in: \"${path}\""
      fi

      # Build file check command
      local uri="//${domain}${port}${share}"
      local cmd="smbclient '${uri}' -U ${user}%${pwd} -c 'cd \"${path}\" ; ls ${name}'"

      # Execute check
      local not_found_regex="^NT_STATUS_NO_SUCH_FILE listing.*${name}$"
      local found_regex="^${name}.* blocks of size .*$"
      local res=0
      res=$(eval "${cmd}")
      res="$(echo "${res%$'\r'}" | xargs)"
      local err=$?
      if [[ ${err} -ne 0 ]]; then
        if [[ ${err} -eq 1 ]] && [[ "${res}" =~ ${not_found_regex} ]]; then
          logInfo "File does not exists. Proceed with upload..."
          logTrace "${res}"
        else
          logFatal "SMB Failed to list files in: ${uri}/${path} (${err}: ${res})"
        fi
      elif [[ -z "${res}" ]]; then
        logFatal "We should not receive an empty response"
      elif [[ "${res}" =~ ${found_regex}  ]]; then
        logInfo "File already exists"
        logTrace "${res}"
        return 0
      else
        echo "${res}"
        logFatal "Did we receive an error?"
      fi

      # Build upload command
      local cmd="smbclient '${uri}' -U ${user}%${pwd} -c 'cd \"${path}\" ; put ${i} ${name}'"

      # Perform the upload
      logInfo "SMB upload \"$1\" to: ${uri}/${path}"
      if ! eval "${cmd}"; then
        logFatal "SMB Failed to upload \"$1\" to: ${uri}/${path}"
      else
        logInfo "Upload of $1 successful"
      fi
      ;;
    scp://*) # SSH

      # Proceed with check
      local cmd="sshpass -p ${pwd} ssh -oStrictHostKeyChecking=no ${user}@${domain}${port} 'test -e ${path}/${name}'"
      local code=0
      eval "${cmd}"
      code=$?
      if [[ ${code} -ne 0 ]]; then
        case ${code} in
          1)
            logInfo "File does not exists. Proceeding with upload"
            ;;
          5)
            logFatal "Permission denied. Check username and password"
            ;;
          127)
            logFatal "Command not found"
            ;;
          255)
            logFatal "Could not resolve location ${domain}"
            ;;
          *)
            logFatal "Unknown error code (${code}) while checking if file exists: ${path}/${name}"
            ;;
        esac
      else
        logInfo "File already exists!"
        return 0
      fi

      # If there's no port, we still need the colon for SCP
      if [[ -z "${port}" ]]; then
        port=":"
      fi

      # Proceed with upload
      cmd="sshpass -p ${pwd} scp -oStrictHostKeyChecking=no ${i} ${user}@${domain}${port}${path}/${name}"
      eval "${cmd}"
      code=$?
      if [[ ${code} -ne 0 ]]; then
        case ${code} in
          2)
            logInfo "File not found. Proceeding with upload"
            ;;
          5)
            logFatal "Permission denied. Check username and password"
            ;;
          255)
            logFatal "Could not resolve location ${domain}"
            ;;
          *)
            logFatal "Unknown error code (${code}) while checking if file exists: ${path}/${name}"
            ;;
        esac
      else
        logInfo "File uploaded successfully!"
      fi

      ;;
    *)
      logFatal "Unsupported protocol: ${XEN_ISO_LIB}"
      ;;
  esac

  return 0
}

#####################################
###### PRIVATE API ##################
#####################################

xe_find_vbd_device_id() {
  # We need a VBD number
  xe_get_vm_param "allowed-VBD-devices"
  local RES=0
  RES=${PARAM//;/} # Seperate by removing the semicolon
  RES=$(printf "%s" "${RES%% *}") # Take the first element

  # Make sure we have a valid number
  local is_number='^[0-9]+$'
  if [[ ! ${RES} =~ ${is_number} ]]; then
    logFatal "We failed to get a device ID using: ${RES}"
  fi

  DEV_ID=${RES}
}

xe_find_vif_device_id() {
  # We need a VIF number
  xe_get_vm_param "allowed-VIF-devices"
  local RES=0
  RES=${PARAM//;/} # Seperate by removing the semicolon
  RES=$(printf "%s" "${RES%% *}") # Take the first element

  # Make sure we have a valid number
  local is_number='^[0-9]+$'
  if [[ ! ${RES} =~ ${is_number} ]]; then
    logFatal "We failed to get a device ID using: ${RES}"
  fi

  DEV_ID=${RES}
}

xe_create_disk() {
  # If we are expecting a specified disk
  if [[ -n "${VM_DISK}" ]]; then
    xe_find_disk

    # If no disk found, create one
    if [[ -z "${VDI_UUID}" ]]; then
      local vdi=""
      local RES=0
      local cmd="\"${XE}\" ${LOGIN} vdi-create sr-uuid=\"${SR_UUID}\" name-label=\"${VM_NAME}_hdd\" virtual-size=\"${VM_DISK}MiB\" --minimal"
      # shellcheck disable=2312
      if ! RES=$(eval "${cmd}" | xargs); then
        logFatal "XE Failed to create disk of ${VM_DISK}MiB on SR: ${VM_SR}"
      elif [[ -z "${RES}" ]]; then
        logFatal "Empty response. Did we fail to create VM?"
      else
        vdi=${RES%$'\r'}
        logInfo "Disk ${vdi} created on: ${VM_DISK}"
      fi

      # Add the newly created disk to the VM
      xe_find_vbd_device_id
      cmd="\"${XE}\" ${LOGIN} vbd-create vm-uuid=\"${VM_UUID}\" device=\"${DEV_ID}\" vdi-uuid=\"${vdi}\" type=Disk mode=RW --minimal"
      # shellcheck disable=2312
      if ! RES=$(eval "${cmd}" | xargs); then
        logFatal "XE Failed to attach disk to: ${VM_NAME}"
      elif [[ -z "${RES}" ]]; then
        logFatal "Empty response. Did we fail to attach disk?"
      else
        VDI_UUID=${vdi}
        logInfo "Disk ${vdi} attached to: ${VM_NAME}"
      fi
    fi
  fi
}

# Called after VM creation, making sure the disks have expected names
xe_rename_new_disks() {
  # If a disk was created (from the template). Make sure it has the expected name
  local RES=0
  local cmd="\"${XE}\" ${LOGIN} vm-disk-list uuid=\"${VM_UUID}\" vdi-params=uuid vbd-params=none --minimal"
  # shellcheck disable=2312
  if ! RES=$(eval "${cmd}" "${LOGIN}" | xargs); then
    logFatal "XE Failed to find the disk"
  elif [[ -z "${RES}" ]]; then
    logWarn "No disks for ${VM_NAME}"
  else
    # We could be returned multiple disks. Loop through them
    RES=${RES%$'\r'}
    echo "Res: ${RES}"
    local nb_disks=0
    nb_disks=$(echo "${RES//,/ }" | wc -w)
    logTrace "${nb_disks} disks were created"
    if [[ "${nb_disks}" -eq 1 ]]; then
      cmd="\"${XE}\" ${LOGIN} vdi-param-set uuid=\"${RES}\" name-label=\"${VM_NAME}_hdd\" --minimal"
      if ! RES=$(eval "${cmd}" | xargs); then
        logFatal "XE Failed to rename: ${i} on VM: ${VM_NAME}"
      elif [[ -n "${RES}" ]]; then
        logFatal "Non-empty response. Did we fail to rename disk: ${RES}"
      else
        logTrace "Rename successful"
      fi
    elif [[ "${nb_disks}" -ge 2 ]]; then
      local disk_count=0
      for i in ${RES//,/ }; do
        cmd="\"${XE}\" ${LOGIN} vdi-param-set uuid=\"${i}\" name-label=\"${VM_NAME}_hdd"
        if [[ ${disk_count} -eq 0 ]]; then
          cmd="${cmd}\" --minimal"
        else
          cmd="${cmd}${disk_count}\" --minimal"
        fi
        if ! RES=$(eval "${cmd}" | xargs); then
          logFatal "XE Failed to rename: ${i} on VM: ${VM_NAME}"
        elif [[ -n "${RES}" ]]; then
          logFatal "Non-empty response. Did we fail to rename disk: ${RES}"
        else
          logTrace "Rename successful"
        fi

        disk_count=$((disk_count + 1))
      done
    else
      logFatal "Invalid result for number of disks: ${nb_disks}"
    fi
  fi
}

xe_add_tags() {
  if [[ -n "${VM_TAG}" ]]; then
    xe_get_vm_param "tags"
    local cur_tags=0
    cur_tags=$(echo "${PARAM}" | xargs)

    for i in ${VM_TAGS//,/ }; do
      local req_tag=${i%$'\r'}
      local found=0
      for j in ${cur_tags//,/ }; do
        local cur_tag=0
        cur_tag=$(echo "${j%$'\r'}" | xargs)
        if [[ "${req_tag}" == "${cur_tag}" ]]; then
          found=1
          logInfo "Tag \"${cur_tag}\" is already present"
          break
        else
          logTrace "Ignoring tag: ${cur_tag}"
        fi
      done

      if [[ ${found} -eq 0 ]]; then
        local RES=0
        local cmd="\"${XE}\" ${LOGIN} vm-param-add uuid=\"${VM_UUID}\" param-name=tags param-key=\"${req_tag}\" --minimal"
        # shellcheck disable=2312
        if ! RES=$(eval "${cmd}" | xargs); then
          logFatal "XE set tag \"${req_tag}\" on VM: ${VM_NAME}"
        elif [[ -n "${RES%$'\r'}" ]]; then
          logFatal "Non-empty response. Did we fail to set tag ${req_tag}: ${RES%$'\r'}"
        else
          RES=${RES%$'\r'}
          logTrace "Tag added: ${req_tag}"
        fi
      fi
    done
  fi
}

# Path Configuration
ROOT="$(git rev-parse --show-toplevel)"
LOGGER_EXEC="${ROOT}/tools/logger-shell/logger.sh"
SHUTILS_EXEC="${ROOT}/tools/shell-utils/shell-utils.sh"

# Import logger
if [[ -z "${LOGFILE}" ]]; then
  # shellcheck disable=1090
  . "${LOGGER_EXEC}"
fi

# shellcheck disable=1090
# Importe shell utilities
. "${SHUTILS_EXEC}"
