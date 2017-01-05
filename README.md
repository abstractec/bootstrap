# bootstrap

Setting up servers by hand is a pain, even servers that are managed via puppet often require some form of configuration and setup in order to allow puppet to be run.

The idea behind this script is to take the pain away from setting up a newly provisioned server.

## Assumptions

The script is built using the assumption that you store your puppet configuration in a github repo and that you are using masterless puppet.

## How it works

This is a simple bootstrapping script that will perform the following actions:

1. Set server hostname (ensure that the fqdn is correct in facter)
2. Run apt-get update and apt-get upgrade to ensure base system is up to date
3. Install the required packages (puppet, git and ruby)
4. Fix broken packages (fixes issue with ping)
5. Install the required ruby gems (puppet librarian)
6. Disable puppet daemon (masterless puppet)
7. Generate default ssh key for root (good practice)
8. Generate deployment key (used for cloning the puppet repo)
9. Update ssh config (create an alias for the repo)
10. Setup known hosts (ssh-keyscan github.com so git clone doesn't ask to accept fingerprint)
11. Add deployment key (Register the deployment key for the repo)
12. Clone the puppet repo
13. Run librarian puppet
14. Run puppet

# Caveats

This script has been developed and tested on Debian 8 (Jessie) only.

# Todo

- [ ] Improve the screen error handling and error reporting
- [ ] Allow the script to install Ruby ~> 2.0.0 - This will allow it to work on Debian 7 (Wheezy)
- [ ] Extend the script to work on Centos
- [ ] Extend the script to allow for fully unmanned install (Default username / password etc)
