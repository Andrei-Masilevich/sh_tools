# ShELL Tools

Tools for Linux user especially that has backend developer role and C/C++/Python3 stack.
It is not only set of sophisticated scripts but Ansible helpers to install workstation environment.

## Base set of Scripts:

* ***
### Cryptography
* ***
* ***create_secret*** - to create random text string 
* ***activate_keys*** - to manage SSH private keys stored in database folder in encrypted manner for both files and file names.
* ***create_pem*** - to create SSH private keys in PEM format
* ***create_cert*** - to create certificates
* ***
* ***encrypt_file*** - to encrypt file
* ***decrypt_file*** - to decrypt file
* ***encrypt_dir*** - to encrypt folder
* ***decrypt_dir*** - to decrypt folder
* ***encrypt_name*** - to encrypt file or folder name
* ***decrypt_name*** - to decrypt file or folder name

### VPN
* ***
* ***vpn_srv_install*** - wizard to install or manage remote VPN server (via SSH connection) 
* ***vpn_cli_openvpn*** - to connect or disconnect client VPN session (OpenVPN implementation)

### Backup
* ***
* ***backup*** - to backup/restore user data created and managed by the scripts (keys, configs, certificates, etc.). It encrypts and inventories the archive.
This script enforce updation for master key.

### Other
* ***
* ***ssh*** - to use SSH client with ecrypted config file
* ***scp*** - to use SCP with ecrypted config file
* ***public_ip*** - to print public IP address for the current node
* ***local_ips*** - to print local IP addresses corresponding to the connected network interfaces
* ***ip_info*** - to get info about own public IP or any other
* ***ip_stat*** - to register public IP in database file to investigate history of it's changing
* ***srcfind*** - specialization for _find_ to search development files
* ***create_files_ext_list*** - to create list for unique file extensions from target directory
* ***copy_dir_schema*** - to copy directory tree structure only (without files)
* ***clear_docker*** - to cleanup disk from docker artifacts
* ***du_progress*** - to monitor directory size (useful while downloading or processing large data to notice space exhausting)
* ***realpath*** - _realpath_ proxy to use on the legacy systems
* ***ssh_diff*** - to compare files on remote and local folders via SSH

## How to install

Use **install** script to deploy only scripts from source to your system:
```sh
bash ./install.sh
```
> It doesn't require privileges escalation because affect $HOME/.local and related local configuration only.

It will create aliases for tools in PATH with name like ***[user]_{script}*** and do some other job to make tools work properly. For instance for user '_alice_' ex. ***alice_public_ip***, ***alice_activate_keys*** will be available.

To install all workstation environment that will include both these scripts and the related packages. Use:
```sh
sudo bash ./install_at_workstation.sh
```
> It requires privileges escalation because of package manager will be used!

or
```sh
sudo bash ./install_at_workstation.sh https://{your_secret_url_with_encrypted_personal_data}
```

Last one uses exported backup archive from public storage. Look at **Export of personal data** to get how to do that.

## Development

This toolset includes custom debugger and simple test framework that allow confident development and support.
To use custom debugger for example for **encrypt_file** script:

```sh
BASH_ENV=debug_env.sh bash ./scripts/encrypt_file.sh -m {file}
```

or for **install** script:
```sh
BASH_ENV=debug_env.sh bash ./install.sh
```

It supports only tracing and locals view. For sophisticated debugging (with breakpoints, stack trace and etc.) in [Visual Studio Code](https://code.visualstudio.com/) you can use extension [Bash Debug](https://marketplace.visualstudio.com/items?itemName=rogalmic.bash-debug).

## If you've created the new one

To add new script files into installation script you should edit *env.inf* file.

For example new script is my_next_cool.sh. Add:

```sh
-./scripts/my_next_cool.sh
```
where _./scripts/my_next_cool.sh_ is repository path.

If this script requires additional lib-file. You should include library path too:

```sh
-./scripts/my_next_cool.sh
-./scripts/lib_for_my_next_cool.sh
```

## Export of personal data

For Ansible installation case it is possible to use link uploaded via https://github.com/Andrei-Masilevich/sh_share.git

