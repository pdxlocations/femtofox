#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try \`sudo\`."
   exit 1
fi
if [ $# -eq 0 ]; then
  echo "No arguments provided."
  echo -e "$help"
  exit 1
fi

args="$@" # arguments to this script
interactive="true"
help=$(cat <<EOF
Arguments:
-h          This message
    Environment - must be first argument:
-x          User UI is not terminal (script interaction unavailable)
    Actions:
-i          Install
-u          Uninstall
-a          Interactive initialization script: code that must be run to initialize the installation prior to use, but can only be run from terminal
-g          Upgrade
-e          Enable service, if applicable
-d          Disable service, if applicable
-s          Stop service
-r          Start/Restart
-l          Command to run software
    Information:
-N          Get name
-A          Get author
-D          Get description
-U          Get URL
-O          Get options supported by this script
-S          Get service status
-E          Get service name
-L          Get install location
-G          Get license
-T          Get license name
-P          Get package name
-C          Get Conflicts
-I          Check if installed. Returns an error if not installed
EOF
)

### For package maintainer:
# Fill the following fields and choose the options that are in use by this package
# Populate the install, uninstall and upgrade functions
# Remember that this script may be launched in terminal, via web UI or another method, so inputs aren't really possible
# Arguments to the script are stored in $args
# This system supports both interactive and non-interactive installs. For non-interactive installs, $interactive="false". In this cause special instructions to the user should be given as user_message, such as `After installation, edit /opt/software/config.ini`
# Successful operations should `exit 0`, fails should `exit 1`
# Messages to the user (such as configuration instructions, explanatory error messages, etc) should be given as: `echo "user_message: text"`
# Everything following `user_message: ` will be displayed prominently to the user, so it must the last thing echoed

name="Meshing Around" # software name
author="Spud" # software author - OPTIONAL
description="Meshing Around is a feature-rich bot designed to enhance your Meshtastic network experience with a variety of powerful tools and fun features. Connectivity and utility through text-based message delivery. Whether you're looking to perform network tests, send messages, or even play games, mesh_bot.py has you covered." # software description - OPTIONAL (but strongly recommended!)
URL="https://github.com/SpudGunMan/meshing-around" # software URL. Can contain multiple URLs - OPTIONAL
options="xiuagedsrNADUOSELGTCI"   # script options in use by software package. For example, for a package with no service, exclude `edsr`
launch=""   # command to launch software, if applicable
service_name="mesh_bot pong_bot mesh_bot_reporting" # the name of the service, such as `chrony`. REQUIRED if service options are in use. If multiple services, separate by spaces "service1 service2"
location="/opt/meshing-around" # install location REQUIRED if not apt installed. Generally, we use `/opt/software-name`
license="$location/LICENSE"     # file to cat to display license
license_name="GPL3"             # license name, such as MIT, GPL3, custom, whatever. short text string
conflicts="TC²-BBS, any other \"full control\" style bots" # comma delineated plain-text list of packages with which this package conflicts. Use the name as it appears in the $name field of the other package. Extra plaintext is allowed, such as "packageA, packageB, any other software that uses the Meshtastic CLI"

# install script
install() {
  if ! git clone https://github.com/spudgunman/meshing-around $location; then
    echo "user_message: Git clone failed. Is internet connected?"
    exit 1
  fi
  pip install -r $location/requirements.txt
  if [ "$interactive" = "true" ]; then #interactive install
    interactive_init
  else
    echo "user_message: IMPORTANT: To complete installation, run \`sudo $location/install.sh\`\nTo change settings, run \`sudo nano $location/config.ini\`"
    exit 0
  fi
}

# uninstall script
uninstall() {
  # stop, disable and remove the service, reload systemctl daemon, remove the installation directory and quit
  for service in $service_name; do
    systemctl stop $service
    systemctl disable $service
    rm "/etc/systemd/system/$service.service"
  done
  systemctl daemon-reload
  systemctl reset-failed
  gpasswd -d meshbot dialout
  gpasswd -d meshbot tty
  gpasswd -d meshbot bluetooth
  groupdel meshbot
  userdel meshbot
  rm -rf /opt/meshing-around
  rm -rf $location
  echo "user_message: Service removed, all files deleted."
  exit 0
}

# code that must be run to initialize the installation prior to use, but can only be run from terminal
interactive_init() {
  "$location/install.sh" | tee /dev/tty
  echo "user_message: To change settings, run \`sudo nano $location/config.ini\`"
  exit 0
}

#upgrade script
upgrade() {
  cd $location
  if ! git pull; then
    echo "user_message: Git pull failed. Is internet connected?"
    exit 1
  fi
  exit 0
}

# Check if already installed. `exit 0` if yes, `exit 1` if no
check() {
  #the following works for cloned repos, but not for apt installs
  if [ -d "$location" ]; then
    exit 0
  else
    exit 1
  fi
}

# display license
license() {
  echo -e "Contents of $license:\n\n   $([[ -f "$license" ]] && awk -v max=2000 -v file="$license" '{ len += length($0) + 1; if (len <= max) print; else if (!cut) { cut=1; printf "%s...\n\nFile truncated, see %s for complete license.", substr($0, 1, max - len + length($0)), file; exit } }' "$license")"
}

while getopts ":h$options" opt; do
  case ${opt} in
    h) # Option -h (help)
      echo -e "$help"
      ;;
    x) # Option -x (no user interaction available)
      echo "Running in non-interactive mode"
      interactive="false"
      ;;
    i) # Option -i (install)
      install
      ;;
    a) # Option -a (interactive initialization)
      interactive_init
      ;;
    u) # Option -u (uninstall)
      uninstall
      ;;
    g) # Option -g (upgrade)
      upgrade
      ;;
    e) # Option -e (Enable service, if applicable)
      systemctl enable $service_name
      ;;
    d) # Option -d (Disable service, if applicable)
      systemctl disable $service_name
      ;;
    s) # Option -s (Stop service)
      systemctl stop $service_name
      ;;
    r) # Option -r (Start/Restart)
      systemctl restart $service_name
      ;;
    l) # Option -l (Run software)
      echo "Launching $name..."
      sudo -u ${SUDO_USER:-$(whoami)} $launch 
      ;;
    N) echo -e $name ;;
    A) echo -e $author ;;
    D) echo $description ;;
    U) echo -e $URL ;;
    O) echo -e $options ;;
    S) # Option -S (Get service status)
      systemctl status $service_name
    ;;
    E) # Option -E (Get service name)
      echo $service_name
    ;;
    L) echo -e $location ;;
    G) # Option -G (Get license) 
      license
    ;;
    T) # Option -T (Get license name) 
      echo $license_name
    ;;
    C) echo -e $conflicts ;;
    I) # Option -I (Check if already installed)
      check
    ;;
  esac
done

exit 0