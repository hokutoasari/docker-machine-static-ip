# docker-machine-static-ip

Specify a static IP for VirtualBox VMs.

## How to use.

1. Download `docker-machine-static-ip.sh` in your path.
2. Grant executable permissions. (`$ chmod +x ./docker-machine-static-ip`)
3. Run `./docker-machine-static-ip --ip IP_ADDRESS DOCKER_MACHINE_NAME`

## Usage

```
Usage: docker-machine-static-ip.sh [Options] DOCKER_MACHINE_NAME

Description:
   RUN 'docker-machine-static-ip.sh --id IP_ADDRESS DOCKER_MACHINE_NAME' to Specify a static IP for VirtualBox VMs.

Options:
   --ip                      Static IP Address input after this: required : ex) 192.168.xx.yy
   help, --help, -h          Print Help (this message) and exit
   version,--version         Print version information and exit
```
