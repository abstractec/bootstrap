#!/usr/bin/env bash
#########################################################################
#                                                                       #
# (c) 2016-2017 AntiPhoton Limited <support@antiphoton.com>             #
# All Rights Reserved.                                                  #
#                                                                       #
# This program is free software: you can redistribute it and/or modify  #
# it under the terms of the GNU General Public License as published by  #
# the Free Software Foundation, either version 3 of the License, or     #
# (at your option) any later version.                                   #
#                                                                       #
# This program is distributed in the hope that it will be useful,       #
# but WITHOUT ANY WARRANTY; without even the implied warranty of        #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
# GNU General Public License for more details.                          #
#                                                                       #
# You should have received a copy of the GNU General Public License     #
# along with this program.  If not, see <http://www.gnu.org/licenses/>. #
#                                                                       #
#########################################################################

#
# Global variables
#
KEY_TYPE='rsa'
BITS=4096
SSH_BASE="${HOME}/.ssh"
SSH_CONFIG="${SSH_BASE}/config"

#
# CLI parameters
#
HOSTNAME=''
GITHUB_USERNAME=''
GITHUB_PASSWORD=''
SERVER_GROUP=''
PUPPET_REPO=''
PUPPET_REPO_OWNER=''

#
# List of required packages
#
PACKAGES=( 'build-essential' 'puppet' 'ruby-dev' 'jq' )

#
# List of required packages
#
BROKEN_PACKAGES=( 'iputils-ping' )

#
# List of required Ruby Gems
#
RUBY_GEMS=( 'librarian-puppet' 'io-console' )

#
# Flags
#
VERBOSE=false
MINUS_X=false
FORCE=false

#
# Pretty ouput
#
CURRENT_STAGE=1

#
# Colours because I can
#
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
RESET=$(tput sgr0)
CLS=$(tput clear)

################################################################################
#                                                                              #
# The main worker functions                                                    #
#                                                                              #
################################################################################

#
# Wrapper for executing commands
#
execute_command()
{
	if [[ "$MINUS_X" = true ]]; then
		echo -e "${YELLOW}	$1${RESET}"
	fi
	if [[ "$VERBOSE" = true ]]; then
		eval $1
	else
		eval $1 >> /dev/null 2>&1
	fi
}

#
# Utility functions
#
contains()
{
	string="$1"
	substring="$2"

	if test "${string#*$substring}" != "$string"; then
		return 0    # $substring is in $string
	fi
	return 1    # $substring is not in $string
}

#
# Because I am lazy
#
show_stage()
{
	if [[ ! -z $1 ]]; then
		echo -e "${GREEN}$CURRENT_STAGE. $1${RESET}"
		CURRENT_STAGE=$((CURRENT_STAGE+1))
	fi
}

show_error()
{
	if [[ ! -z $1 ]]; then
		echo -e "${RED}$1${RESET}"
	fi
}

show_warning()
{
	if [[ ! -z $1 ]]; then
		echo -e "${YELLOW}$1${RESET}"
	fi
}

setup_hostname()
{
	show_stage "Setting hostname"

	execute_command "echo ${HOSTNAME} >> /etc/hostname"
	execute_command "hostname ${HOSTNAME}"
}

update_existing_packages()
{
	show_stage "Updating current packages"

	execute_command "apt-get update"
	execute_command "apt-get -y upgrade"
}

install_required_packages()
{
	show_stage "Installing required packages"

	for i in "${PACKAGES[@]}"
	do
		execute_command "apt-get -y install ${i}"
	done
}

fix_broken_packages()
{
	show_stage "Fixing broken packages"

	for i in "${BROKEN_PACKAGES[@]}"
	do
		execute_command "apt-get -y install --reinstall ${i}"
	done
}

install_required_ruby_gems()
{
	show_stage "Installing required Ruby Gems"

	for i in "${RUBY_GEMS[@]}"
	do
		execute_command "gem install ${i}"
	done
}

disable_puppet_daemon()
{
	show_stage "Disable Puppet Daemon"

	execute_command "/etc/init.d/puppet stop"
	execute_command "update-rc.d -f puppet remove"
}

setup_custom_fact()
{
	show_stage "Setting up custom fact"

	execute_command "mkdir -p /etc/facter/facts.d/"
	execute_command "echo '#!/usr/bin/env bash' > /etc/facter/facts.d/server_group.sh"
	execute_command "echo \"echo server_group=${SERVER_GROUP}\" >> /etc/facter/facts.d/server_group.sh"
	execute_command "chmod 755 /etc/facter/facts.d/server_group.sh"
}

generate_default_ssh_key()
{
	show_stage "Generating default ssh key"

	if [[ -f "${SSH_BASE}/id_${KEY_TYPE}" ]]; then
		if [[ "$FORCE" = true ]]; then
			execute_command "rm -f \"${SSH_BASE}/id_${KEY_TYPE}\""
		else
			show_error "${SSH_BASE}/id_${KEY_TYPE} - already exists"
			while true; do
				read -p "overwrite? " yn
				case $yn in
					[Yy]* ) rm -f "${SSH_BASE}/id_${KEY_TYPE}"; break;;
					[Nn]* ) return; break;;
					* ) echo "Please answer yes or no.";;
				esac
			done
		fi
	fi
	execute_command "ssh-keygen -t ${KEY_TYPE} -b ${BITS} -N '' -C 'Default SSH Key' -f ${SSH_BASE}/id_${KEY_TYPE} -q"
	execute_command "chmod 400 ${SSH_BASE}/id_${KEY_TYPE}"
}

generate_deployment_key()
{
	show_stage "Generating deployment key for ${PUPPET_REPO}"

	if [[ -f "${SSH_BASE}/id_${KEY_TYPE}_${PUPPET_REPO}" ]]; then
		if [[ "$FORCE" = true ]]; then
			execute_command "rm -f \"${SSH_BASE}/id_${KEY_TYPE}_${PUPPET_REPO}\""
		else
			show_error "${SSH_BASE}/id_${KEY_TYPE}_${PUPPET_REPO} - already exists"
			while true; do
				read -p "overwrite? " yn
				case $yn in
					[Yy]* ) rm -f "${SSH_BASE}/id_${KEY_TYPE}_${PUPPET_REPO}"; break;;
					[Nn]* ) return; break;;
					* ) echo "Please answer yes or no.";;
				esac
			done
		fi
	fi
	execute_command "ssh-keygen -t ${KEY_TYPE} -b ${BITS} -N '' -C \"${PUPPET_REPO} deployment key\" -f ${SSH_BASE}/id_${KEY_TYPE}_${PUPPET_REPO} -q"
	execute_command "chmod 400 ${SSH_BASE}/id_${KEY_TYPE}_${PUPPET_REPO}"
}

update_ssh_config()
{
	show_stage "Setting up SSH Config"

	if [[ -f ${SSH_CONFIG} ]]; then
		grep "Host ${PUPPET_REPO}-repo github.com" ${SSH_CONFIG} > /dev/null
		if [[ $? -eq 0 ]]; then
			show_warning "\tSSH Config exists for ${PUPPET_REPO} - Skipping"
			return
		fi
	fi

	execute_command "echo -e \"Host ${PUPPET_REPO}-repo github.com\" >> ${SSH_CONFIG}"
	execute_command "echo -e \"\tHostname github.com\" >> ${SSH_CONFIG}"
        execute_command "echo -e \"\tIdentityFile ~/.ssh/id_${KEY_TYPE}_${PUPPET_REPO}\" >> ${SSH_CONFIG}"
        execute_command "echo -e \"\tUser git\" >> ${SSH_CONFIG}"
	execute_command "chmod 644 ${SSH_CONFIG}"
}

setup_known_hosts()
{
	show_stage "Setting up known host fingerprint for github.com"

	github_fingerprint=$(ssh-keyscan -H github.com 2>/dev/null)

	if [[ -f "${SSH_BASE}/known_hosts" ]]; then
		key=$(echo "${github_fingerprint}" | cut -d " " -f2-)
		grep "${key}" "${SSH_BASE}/known_hosts" > /dev/null
		if [[ $? -eq 0 ]]; then
			show_warning "\tSSH fingerprint for github.com already exists - Skipping"
			return
		fi
	fi
	echo $github_fingerprint >> "${SSH_BASE}/known_hosts"
}

add_deployment_key()
{
	show_stage "Adding deployment key to ${PUPPET_REPO}"

	KEY_VALUE=$(<"${SSH_BASE}/id_${KEY_TYPE}_${PUPPET_REPO}.pub")
	response=$(curl -s -X POST -u ${GITHUB_USERNAME}:${GITHUB_PASSWORD} https://api.github.com/repos/${PUPPET_REPO_OWNER}/${PUPPET_REPO}/keys -d "{\"title\":\"Deployment key for ${HOSTNAME}\",\"read_only\":true,\"key\":\"${KEY_VALUE}\"}")

	contains "${response}" "created_at"
	if [[ $? -eq 1 ]]; then
		show_error "There was a problem adding the deployment key"
		echo ${response} | jq .

		while true; do
			read -p "abort? " yn
			case $yn in
				[Yy]* ) exit; break;;
				[Nn]* ) break;;
				* ) echo "Please answer yes or no.";;
			esac
		done
	fi
}

clone_puppet_repo()
{
	show_stage "Cloning the puppet repository"

	execute_command "rm -rf /etc/puppet"
	execute_command "git clone ssh://git@puppet-repo/${PUPPET_REPO_OWNER}/${PUPPET_REPO}.git /etc/puppet"
}

run_librarian_puppet()
{
	show_stage "Running librarian puppet"

	execute_command "cd /etc/puppet"
	execute_command "librarian-puppet install"
}

run_puppet()
{
	show_stage "Running puppet"

	execute_command "puppet apply /etc/puppet/manifests/site.pp"
}

#
# The actual main part of the script!
#
main()
{
	setup_hostname
	update_existing_packages
	install_required_packages
	fix_broken_packages
	install_required_ruby_gems
	disable_puppet_daemon
	setup_custom_fact
	generate_default_ssh_key
	generate_deployment_key
	update_ssh_config
	setup_known_hosts
	add_deployment_key
	clone_puppet_repo
	run_librarian_puppet
	run_puppet
}


check_root()
{
	if [[ $EUID -ne 0 ]]; then
		show_error "This script must be run as root"
		exit 1
	fi
}

usage()
{
	echo "Usage: $0 [-hvxf] -H fqdn -u usename -p password -g group -o repo owner -r repo"
	echo " "
	echo " -h    : This help page"
	echo " -v    : verbose (very noisy)"
	echo " -x    : Show all commands being execute (think bash -x)"
	echo " -f    : Force (This will overwrite ssh keys if they exist)"
	echo " -H    : Hostname of the server"
	echo " -u    : Github username"
	echo " -p    : Github password"
	echo " -g    : Server Group"
	echo " -o    : Puppet Repo owner"
	echo " -r    : Puppet Repo (Repo name NOT full url)"
	echo " "
	exit 1;
}

init()
{
	while getopts "hvxfH:u:p:g:o:r:a:" arg; do
		case $arg in
			h)
				usage
				;;
			v)
				VERBOSE=true
				;;
			x)
				MINUS_X=true
				;;
			f)
				FORCE=true
				;;
			H)
				HOSTNAME=$OPTARG
				;;
			u)
				GITHUB_USERNAME=$OPTARG
				;;
			p)
				GITHUB_PASSWORD=$OPTARG
				;;
			g)
				SERVER_GROUP=$OPTARG
				;;
			o)
				PUPPET_REPO_OWNER=$OPTARG
				;;
			r)
				PUPPET_REPO=$OPTARG
				;;
		esac
	done

	[[ -z $HOSTNAME ]] && usage
	[[ -z $GITHUB_USERNAME ]] && usage
	[[ -z $GITHUB_PASSWORD ]] && usage
	[[ -z $PUPPET_REPO_OWNER ]] && usage
	[[ -z $PUPPET_REPO ]] && usage
}

check_root
init "$@"
main

