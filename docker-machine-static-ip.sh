#!/usr/bin/env bash

####################
# How to work this.
#
#   1. SSH onto the docker machine
#       $ docker-machine ssh DOCKER_MACHINE_NAME
#   2. Add/Edit the boot2docker startup script in /var/lib/boot2docker/bootsync.sh
#       $ sudo vi /var/lib/boot2docker/bootsync.sh
#       #!/bin/sh
#       /etc/init.d/services/dhcp stop
#       ifconfig eth1 192.168.99.50 netmask 255.255.255.0 broadcast 192.168.99.255 up
#   3. Grant permission
#       $ sudo chmod 755 /var/lib/boot2docker/bootsync.sh
#   4. Restart machine and regenerate certs
#       $ docker-machine restart default
#       $ docker-machine regenerate-certs default
#
####################

declare -r OK=0
declare -r ERROR=1
declare -r PROGNAME=$(basename $0)
declare -r VERSION="0.0.1"
declare -r CMD_DOCKER_MACHINE=docker-machine
declare -r IP_ADDRESS_EXAMPLE="192.168.xx.yy"

declare -r BOOTSYNC_SH_PATH="/var/lib/boot2docker/bootsync.sh"

usage() {
cat <<_EOT_
Usage: $PROGNAME [Options] DOCKER_MACHINE_NAME

Description:
   RUN '$PROGNAME --id IP_ADDRESS DOCKER_MACHINE_NAME' to Specify a static IP for VirtualBox VMs.

Options:
   --ip                      Static IP Address input after this: required : ex) $IP_ADDRESS_EXAMPLE
   help, --help, -h          Print Help (this message) and exit
   version,--version         Print version information and exit
_EOT_
  exit 1
}

version() {
  echo $VERSION
}

exists_docker_machine() {
  local result=$ERROR
  if which $CMD_DOCKER_MACHINE 1>/dev/null 2>/dev/null ; then
    result=${OK}
  fi
  return ${result}
}

validate_machines_required() {
  local result=$ERROR
  local machines=($@)
  local length=${#machines[@]}

  [ ${length} == 0 ] && result=$ERROR || result=$OK
  return ${result}
}
validate_machines_length() {
  local result=$ERROR
  local machines=($@)
  local length=${#machines[@]}

  [ ${length} != 1 ] && result=$ERROR || result=$OK
  return ${result}
}

validate_exists_machine() {
  local result=$ERROR
  local machine="$1"

  if docker-machine inspect ${machine} > /dev/null ; then
    result=$OK
  fi
  return ${result}
}

validate_machine_driver_is_virtualbox() {
  local result=$ERROR
  local machine="$1"

  if docker-machine inspect ${machine} | grep DriverName | grep -q virtualbox ; then
    result=$OK
  fi
  return ${result}
}

validate_ip() {
  local  ip=$1
  local  stat=1

  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    ip=($ip)
    IFS=$OIFS
    [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
      && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
      stat=$?
  fi
  return $stat
}

validate_private_ip() {
  local result=$ERROR
  local ip="$1"

  # REGEXP FOR CLASS A NETWORKS :
  #   (10)(\.([2][0-5][0-5]|[1][0-9][0-9]|[1-9][0-9]|[0-9])){3}
  # REGEXP FOR CLASS B NETWORKS :
  #   (172)\.(1[6-9]|2[0-9]|3[0-1])(\.([2][0-5][0-5]|[1][0-9][0-9]|[1-9][0-9]|[0-9])){2}
  # REGEXP FOR CLASS C NETWORKS :
  #   (192)\.(168)(\.([2][0-5][0-5]|[1][0-9][0-9]|[1-9][0-9]|[0-9])){2}

  if [[ "${ip}" =~ ^(10)(\.([2][0-5][0-5]|[1][0-9][0-9]|[1-9][0-9]|[0-9])){3} ]] ; then
    result=$OK
  elif [[ "${ip}" =~ ^(172)\.(1[6-9]|2[0-9]|3[0-1])(\.([2][0-5][0-5]|[1][0-9][0-9]|[1-9][0-9]|[0-9])){2} ]]; then
    result=$OK
  elif [[ "${ip}" =~ ^(192)\.(168)(\.([2][0-5][0-5]|[1][0-9][0-9]|[1-9][0-9]|[0-9])){2} ]]; then
    result=$OK
  fi
  return ${result}


  [[ "$ip" =~ ^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.) ]] && result=$OK || result=$ERROR
  return ${result}
}

validate_unique_ip_in_docker_machine() {
  local result=$ERROR
  local ip="$1"
  local exists=0
  local OIFS=$IFS
  IFS=$'\n'
  for line in $($CMD_DOCKER_MACHINE ls)
  do
    if [[ "${line}" =~ .*"${ip}:".* ]] ; then
      exists=1
    fi
  done
  IFS=$OIFS

  [ ${exists} -eq 0 ] && result=$OK

  return ${result}
}

get_broadcast() {
  local ip="$1"
  local OIFS=$IFS
  IFS="."
  local ary=($ip)
  IFS=$OIFS

  local sect1=(${ary[@]:0})
  local sect2=(${ary[@]:1})
  local sect3=(${ary[@]:2})

  echo "${sect1}.${sect2}.${sect3}.255"
}

apply_static_ip() {
  local ip=$1
  local machine=$2
  local broadcast=$(get_broadcast "${ip}")
  local bootsyncsy="#!/bin/sh\n/etc/init.d/services/dhcp stop\nifconfig eth1 ${ip} netmask 255.255.255.0 broadcast ${broadcast} up"

  $CMD_DOCKER_MACHINE ssh ${machine} "echo -e \"$bootsyncsy\" | sudo tee -a ${BOOTSYNC_SH_PATH} > /dev/null && sudo chmod 755 ${BOOTSYNC_SH_PATH}"
  return $?
}

main() {
  local ip=""
  local machines=()
  local machine=""
  local result=$ERROR
  local ANS=""

  # exists docker-machine
  if ! exists_docker_machine ; then
    echo "Error: $CMD_DOCKER_MACHINE command is not found. Please install docker-machine first."
    exit $ERROR
  fi

  if [[ "${#@}" -eq 0 ]]; then
    usage
    exit $ERROR
  fi

  # options
  for OPT in "$@"
  do
    case "$OPT" in
      'help'|'-h'|'--help' )
        usage
        exit $OK
        ;;
      'version'|'--version' )
        version
        exit $OK
        ;;
      '--ip' )
        shift 1
        ip="$1"
        shift 1
        ;;
      *)
        machines+=( "$1" )
        shift 1
        ;;
    esac
  done

  # validate is local ip address
  ## 54.238.184.225

  if [[ "${#ip}" -eq 0 ]] ; then
    echo "Error: IP Address is required. ex) --ip $IP_ADDRESS_EXAMPLE"
    exit $ERROR
  fi

  # validate ip
  if ! validate_ip ${ip} ; then
    echo "Error: ${ip} is invalid IP Address."
    exit $ERROR
  fi

  # validate private ip
  if ! validate_private_ip ${ip} ; then
    echo "Error: ${ip} is not private IP Address."
    exit $ERROR
  fi

  # validate_unique_ip_in_docker_machine
  if ! validate_unique_ip_in_docker_machine ${ip} ; then
    echo "Error: ${ip} is already used in other VMs IP address. see '$CMD_DOCKER_MACHINE ls'."
    exit $ERROR
  fi

  # validate machines is required
  if ! validate_machines_required "${machines[@]}" ; then
    echo "Error: Missing parameter. DOCKER_MACHINE_NAME is required."
    exit $ERROR
  fi

  # validate machines length(Specify only one parameter)
  if ! validate_machines_length "${machines[@]}" ; then
    echo "Error: '${machines[@]}' is Invalid parameter. Specify only one parameter."
    exit $ERROR
  fi

  # set machine variable
  machine="${machines[@]}"

  # validate_exists_machine
  if ! validate_exists_machine ${machine} ; then
    # Host does not exist, Error Message provide by docker-machine inspect ${machine} command.
    exit $ERROR
  fi

  # validate machine name's driver is virtualbox
  if ! validate_machine_driver_is_virtualbox ${machine} ; then
    echo "Error: ${machine} Driver is not virtualbox."
    exit $ERROR
  fi

  # apply static ip
  if ! apply_static_ip ${ip} ${machine} ; then
    echo "Whoops! something wrong..."
    exit $ERROR
  fi

  # Restart machine and regenerate certs
  echo "Restart machine and Regenerate certs? [Y/n]"
  read ANS
  case $ANS in
    "" | "Y" | "y" | "yes" | "Yes" | "YES" )
      $CMD_DOCKER_MACHINE restart ${machine} && $CMD_DOCKER_MACHINE regenerate-certs ${machine} -f
      ;;
    * )
      cat << EOT
You must be restart machine and regenerate certs. like bellow commands.
     $ $CMD_DOCKER_MACHINE restart ${machine}
     $ $CMD_DOCKER_MACHINE regenerate-certs ${machine}

EOT
      ;;
  esac

  return $OK
}

main $@
