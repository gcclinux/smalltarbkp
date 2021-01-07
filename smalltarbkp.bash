#!/usr/bin/env bash
#
# @author:            		Ricardo Wagemaker (["java"] + "@" + "wagemaker.co.uk") 2017-2020
# @name:			smalltarbkp
# @created: 			Sun 6 Aug 08:17:41 BST 2017 - original v1.0
# @updated: 			Tue  1 Dec 21:05:59 GMT 2020
# @tested OS:			Ubuntu 20.04 & Fedora 33 & Raspbian 10
# @tested MYSQL: 		mysql Ver 14.14 Distrib 5.7.28 | mysql Ver 15.1 Distrib 10.3.22-MariaDB
# @tested PostgreSQL:		psql 12.5-0ubuntu0.20.04.1
#
#######################################################################
# NOTES & INSTRUCTIONS 			 			      #
#######################################################################
# @WARNING:	ANY MODIFICATIONS IS AT YOUR OWN RISK                 #
# @WARNING:	SCRIPT UPDATES WILL NOT PRESERVE ANY MODIFICATIONS    #
#######################################################################

## TODO - Check if all required software is installed before each backup  			- Build 42
## TODO - Check if Local_target exist before each backup					- Build 43
## TODO - When expiring images must only expire from it's own HOST rather that entire folder	- Build 44
## TODO - Add archive FLAG - Means won't be deleted by the retention only manually		- Build 45

CONFIG=${HOME}/.config/.smalltarbkp.cnf				     # Config file for v4.0 and above
if [[ ! -f ${CONFIG} ]]; then
	touch ${CONFIG};
fi
. ${CONFIG};							     # Initiate CONFIG file

GOOD="\033[0;32m\xE2\x9C\x94\033[0m"
MISSING="\033[1;31m\xE2\x9C\x96\033[0m"
NEED="\033[1;31m\xE2\x9E\xA1\033[0m"
RULLER="\e[33m###########################################################################################\033[0m"

VERSION="5.0 - Build 41"					      # Script version and build number
TMP=""                                                                # Temprary store setup varible
START=""                                                              # Boolean START = true/false
SETCOUNT=""                                                           # Boolean SETCOUNT = true/false
SRCDIR="${2}"                                                         # Location of SOURCE passed a a argument
FILE_NAME=""                                                          # Pre-set file name
BKPSIZE=0                                                             # Size of the backups only availble in verbose mode
SECONDS=0                                                             # Start Time of script "0"
TIME=`date +%s`                                                       # Backup file timestamp
DATE=`date +%Y-%m-%d`                                                 # Backup target folder
NAME=$(basename $0)						      # Script name
HOSTNAME=`uname -n | tr " " "_" | tr "-" "_"`                         # Hostname
SETUP=`echo $SETUP`                                                   # Setup complete status
LOCAL_TARGET=`echo $LOCAL_TARGET`				      # NFS mount / USB / Cloud drive, etc
IMAGE_SIZE=`echo $IMAGE_SIZE`					      # Split tar file $SIZE in MEGABYTES
RETENTION=`echo $RETENTION`                                           # Retention period of the backups in days +1
FULLFREQ=`echo $FULLFREQ`                                             # FULL Backup frequency in runs
ENCPASS=`echo $ENCPASS`                                               # Encryption password
ENCRYPT=`echo $ENCRYPT`                                               # Boolean ENCRYPT = true/false
TARGET=`echo $TARGET`                                                 # Top level target folder
MEGA_TRUE=`echo $MEGA_TRUE`                                           # Configure for MEGA.nz
MEGA_SIZE=`echo $MEGA_SIZE`                                           # Initial Cloud size
MEGA_EMAIL=`echo $MEGA_EMAIL`                                         # MEGA.nz login ID
MEGA_PASSWORD=`echo $MEGA_PASSWORD`                                   # MEGA.nz account password
MEGA_BOTH=`echo $MEGA_BOTH`                                           # Keep local & MEGA backups true/false
NEXTCLOUD_TRUE=`echo $NEXTCLOUD_TRUE`                                 # Configure for Nextcloud
NEXTCLOUD_URL=`echo $NEXTCLOUD_URL`                                   # Initial Cloud size
NEXTCLOUD_LOGIN=`echo $NEXTCLOUD_LOGIN`                               # MEGA.nz login ID
NEXTCLOUD_PASS=`echo $NEXTCLOUD_PASS`                                 # MEGA.nz account password
NEXTCLOUD_BOTH=`echo $NEXTCLOUD_BOTH`                                 # Keep local & Nextcloud backups true/false
MEGAcmd=`echo ${MEGAcmd}`                                             # Store MEGAcmd version
GAWK=`echo ${GAWK}`                                                   # Store GAWK version
OPENSSL=`echo ${OPENSSL}`                                             # Store OPENSSl version
CADAVER=`echo ${CADAVER}`                                             # Store CADAVER version
MYSQLDUMP=`echo ${MYSQLDUMP}`                                         # Store Mysqldump version
CURL=`echo ${CURL}`                                                   # Store CURL version
COUNT=`echo $COUNT`                                                   # Number of backup images
ERROR=/tmp/${NAME}.log                                                # Error log
NEWNAME=`echo ${4} | tr " " "_" | tr "-" "_"`                         # Removing Spaces and dashes
DBHOST=`echo ${9} | tr "." "_" | tr "-" "_"`                          # Removing Spaces and dashes
DESDIR="${LOCAL_TARGET}/${TARGET}/${DATE}"                            # Destination of backup file.
SNF=${SRCDIR}/snapshot.info                                           # Snapshot file name and location
URL="https://bit.ly/3qctuvQ"                                          # Link to the latest script version

#######################################################################
# SMALLTARBKP FUNCTIONS
#######################################################################

function version_ctl () {
          if [ -x /usr/bin/mega-version ]; then
                  MEGAcmdV=`/usr/bin/mega-version | awk '{print $3}' | sed 's/.$//'`
                  if [[ -z ${MEGAcmd} ]]; then
                          echo "MEGAcmd=\"${MEGAcmdV}\"" >> ${CONFIG}
                  else
                          sed -i "s/MEGAcmd=\"${MEGAcmd}\"/MEGAcmd=\"${MEGAcmdV}\"/" ${CONFIG}
                  fi
          fi

          if [ -x /usr/bin/gawk ]; then
                  GAWKV=`/usr/bin/gawk -V | head -1 | awk '{print $3}' | sed 's/.$//'`
                  if [[ -z ${GAWK} ]]; then
                          echo "GAWK=\"${GAWKV}\"" >> ${CONFIG}
                  else
                          sed -i "s/GAWK=\"${GAWK}\"/GAWK=\"${GAWKV}\"/" ${CONFIG}
                  fi
          fi

          if [ -x /usr/bin/openssl ]; then
                  OPENSSLV=`/usr/bin/openssl version | awk '{print $2}'`
                  if [[ -z ${OPENSSL} ]]; then
                          echo "OPENSSL=\"${OPENSSLV}\"" >> ${CONFIG}
                  else
                          sed -i "s/OPENSSL=\"${OPENSSL}\"/OPENSSL=\"${OPENSSLV}\"/" ${CONFIG}
                  fi
          fi

          if [ -x "/usr/bin/mysqldump" ]; then
                  MYSQLDUMPV=`/usr/bin/mysqldump -V | awk '{print $3}'`
                  if [[ -z ${MYSQLDUMP} ]]; then
                          echo "MYSQLDUMP=\"${MYSQLDUMPV}\"" >> ${CONFIG}
                  else
                          sed -i "s/MYSQLDUMP=\"${MYSQLDUMP}\"/MYSQLDUMP=\"${MYSQLDUMPV}\"/" ${CONFIG}
                  fi
          fi

          if [ -x "/usr/bin/pg_dump" ]; then
                  PG_DUMPV=`/usr/bin/pg_dump -V | awk '{print $3}'`
                  if [[ -z ${PG_DUMP} ]]; then
                          echo "PG_DUMP=\"${PG_DUMPV}\"" >> ${CONFIG}
                  else
                          sed -i "s/PG_DUMP=\"${PG_DUMP}\"/PG_DUMP=\"${PG_DUMPV}\"/" ${CONFIG}
                  fi
          fi

          if [ -x /usr/bin/cadaver ]; then
                  CADAVERV=`/usr/bin/cadaver --version | grep cadaver | awk '{print $2}'`
                  if [[ -z ${CADAVER} ]]; then
                          echo "CADAVER=\"${CADAVERV}\"" >> ${CONFIG}
                  else
                          sed -i "s/CADAVER=\"${CADAVER}\"/CADAVER=\"${CADAVERV}\"/" ${CONFIG}
                  fi
          fi
          if [ -x /usr/bin/curl ]; then
                  CURLV=`/usr/bin/curl --version | grep curl | awk '{print $2}'`
                  if [[ -z ${CURL} ]]; then
                          echo "CURL=\"${CURLV}\"" >> ${CONFIG}
                  else
                          sed -i "s/CURL=\"${CURL}\"/CURL=\"${CURLV}\"/" ${CONFIG}
                  fi
          fi
  }

function check() {
        version_ctl;
        if [[ ${1} != "false" ]];then
                echo "version: ${VERSION}"
                echo ""
                banner;
        fi
	echo ""
	echo -e "${RULLER}"
        echo ""
	if [ ! -x "/usr/bin/mega-login" ]; then
		echo -e "${MISSING} MISSING: MEGACMD NOT INSTALLED! { REQUIRED FOR MEGA.nz CLOUD BACKUPS! }"
        else
                echo -e "${GOOD} MEGA.nz INSTALLED (VERSION: ${MEGAcmd})"
	fi
	if [ ! -x "/usr/bin/gawk" ]; then
		echo -e "${MISSING} MISSING: GAWK NOT INSTALLED! { REQUIRED FOR FORMATTING REPORTS AND RESTORES! }"
        else
                echo -e "${GOOD} GAWK INSTALLED (VERSION: ${GAWK})"
	fi
	if [ ! -x "/usr/bin/openssl" ]; then
		echo -e "${MISSING} MISSING: OPENSSL NOT INSTALLED! { REQUIRED FOR ENCRYPTION! }"
        else
                echo -e "${GOOD} OPENSSL INSTALLED (VERSION: ${OPENSSL})"
	fi
	if [ ! -x "/usr/bin/mysqldump" ]; then
		echo -e "${MISSING} MISSING: MYSQLDUMP NOT INSTALLED! { REQUIRED FOR MYSQL OR MARIA BACKUPS! }"
        else
                echo -e "${GOOD} MYSQLDUMP INSTALLED (VERSION: ${MYSQLDUMP})"
	fi
        if [ ! -x "/usr/bin/pg_dump" ]; then
		echo -e "${MISSING} MISSING: PG_DUMP NOT INSTALLED! { REQUIRED FOR PostgreSQL BACKUPS! }"
        else
                echo -e "${GOOD} PG_DUMP INSTALLED (VERSION: ${PG_DUMP})"
	fi
        if [ ! -x "/usr/bin/cadaver" ]; then
                echo -e "${MISSING} MISSING: CADAVER NOT INSTALLED! { REQUIRED FOR NEXTCLOUD CLOUD BACKUPS! }"
        else
                echo -e "${GOOD} CADAVER INSTALLED (VERSION: ${CADAVER})"
        fi
        if [[ ! -x "/usr/bin/curl" ]] ; then
                echo -e "${MISSING} MISSING: CURL NOT INSTALLED! { CURL REQUIRED FOR SCRIPT UPGRADES }"
        else
                echo -e "${GOOD} CURL INSTALLED (VERSION: ${CURL})"
        fi
        echo ""
        echo -e "${GOOD} ADDITIONAL COMMANDS USED ${GOOD}"
        echo -e "${GOOD} $(which ls)"
        echo -e "${GOOD} $(which mv)"
        echo -e "${GOOD} $(which rm)"
        echo -e "${GOOD} $(which du)"
        echo -e "${GOOD} $(which wc)"
	echo -e "${GOOD} $(which cat)"
        echo -e "${GOOD} $(which tar)"
        echo -e "${GOOD} $(which sed)"
        echo -e "${GOOD} $(which tee)"
        echo -e "${GOOD} $(which sort)"
        echo -e "${GOOD} $(which tail)"
        echo -e "${GOOD} $(which echo)"
        echo -e "${GOOD} $(which mkdir)"
        echo -e "${GOOD} $(which which)"
        echo -e "${GOOD} $(which touch)"
        echo -e "${GOOD} $(which split)"
        echo -e "${GOOD} $(which printf)"
        echo ""

        if [[ ! ${SETUP} == "true" ]]; then
                echo ""
                echo -e "${MISSING} WARNING: SETUP NOT DONE!"
                echo -e "${NEED} RUN: 	${NAME} [--setup]"
        else
                echo ""
                echo -e "${GOOD} SMALLTARBKP CONFIGURED { VERSION: ${VERSION} }"
        fi
        echo ""
		echo -e "${RULLER}"
  }


function banner () {
  echo -e "\e[33m
  ███████╗███╗   ███╗ █████╗ ██╗     ██╗  ████████╗ █████╗ ██████╗ ██████╗ ██╗  ██╗██████╗
  ██╔════╝████╗ ████║██╔══██╗██║     ██║  ╚══██╔══╝██╔══██╗██╔══██╗██╔══██╗██║ ██╔╝██╔══██╗
  ███████╗██╔████╔██║███████║██║     ██║     ██║   ███████║██████╔╝██████╔╝█████╔╝ ██████╔╝
  ╚════██║██║╚██╔╝██║██╔══██║██║     ██║     ██║   ██╔══██║██╔══██╗██╔══██╗██╔═██╗ ██╔═══╝
  ███████║██║ ╚═╝ ██║██║  ██║███████╗███████╗██║   ██║  ██║██║  ██║██████╔╝██║  ██╗██║
  ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝╚═╝
  \033[0m"
  }

function help () {
  	echo "version: $VERSION"
  	if [[ ${SETUP} == "FALSE" ]] || [[ -z ${SETUP} ]]; then
  		if [[ ${1} != "--setup" ]]; then
  		        check "false";
  		fi
  	fi
  banner;
  echo -e "usage: ${GOOD} ${NAME} [--help] [ report | restore | backup | db | cloud]"
  echo -e "usage: ${GOOD} ${NAME} [--setup]"
  echo -e "usage: ${GOOD} ${NAME} [--check]"
  echo -e "usage: ${GOOD} ${NAME} [--details]"
  echo -e "usage: ${GOOD} ${NAME} [--upgrade]"
  echo -e "usage: ${GOOD} ${NAME} [--purge-maintanance]"
  echo -e "usage: ${GOOD} ${NAME} [--purge-manually] [-local|-mega |-nextcloud]"
  echo -e "usage: ${GOOD} ${NAME} [--images] [-local|-mega |-nextcloud] [-retrieve|-report] [-s pattern]"
  echo -e "usage: ${GOOD} ${NAME} [--path <path> -name <name>] [-local|-mega |-nextcloud] [-full] [-verbose]"
  echo -e "usage: ${GOOD} ${NAME} [--include <path-to-include-list> -name <name>] [-local|-mega |-nextcloud] [-verbose]"
  echo -e "usage: ${GOOD} ${NAME} [--mysql -dbuser <name> -dbpass <password> -dbname <database>] -host <hostname> [-full|-data|-schema] [-local|-mega |-nextcloud]"
  echo -e "usage: ${GOOD} ${NAME} [--psql -dbuser <name> -dbpass <password> -dbname <database>] -host <hostname> [-full|-data|-schema] [-local|-mega |-nextcloud]"
  echo ""
  }

function help-report () {
          echo ""
          echo -e "${GOOD} REPORT BACKUP IMAGES FROM LOCAL OR MEGA OR NEXTCLOUD SERVER"
          echo -e "usage: 	${NAME} [--images] [-local|-mega |-nextcloud] [-report]"
          echo ""
          echo -e "${GOOD} REPORT BACKUP IMAGES FROM LOCAL OR MEGA OR NEXTCLOUD SERVER WITH SEARCH STRING"
          echo -e "usage: 	${NAME} [--images] [-local|-mega |-nextcloud] [-report] [-s pattern]"
          echo ""
  }

function help-restore () {
        echo ""
        echo -e "${GOOD} YOU CAN DECRYPT BACKUP IMAGES MANUALLY IF YOU WANT"
        echo "usage:  openssl aes-256-cbc -d -a -pbkdf2 -in  <FILE_NAME>.enc -out <FILE_NAME> -pass pass:'PassW0rd'"
        echo ""
        echo -e "${GOOD} RESTORE BACKUP IMAGES FROM LOCAL OR MEGA OR NEXTCLOUD SERVERS"
        echo -e "usage: 	${NAME} [--images] [-local|-mega |-nextcloud] [-restore]"
        echo ""
        echo -e "${GOOD} RESTORE BACKUP IMAGES FROM LOCAL OR MEGA OR NEXTCLOUD SERVERS WITH SEARCH STRING"
        echo -e "usage: 	${NAME} [--images] [-local|-mega |-nextcloud] [-restore] [-s pattern]"
        echo ""
        echo -e "${GOOD} RESTORE OR VIEW RETRIEVED BACKUP IMAGES"
        echo "list: 		cat <BACKUP_FILE>.tar.gz-* | tar tz				--> List All Files "
        echo "restore: 	cat <BACKUP_FILE>.tar.gz-* | tar xvz				--> Restore All Files"
        echo "search: 	cat <BACKUP_FILE>.tar.gz-* | tar tz | grep <PATTERN>		--> Search pattern"
        echo "restore: 	cat <BACKUP_FILE>.tar.gz-* | tar xz <FULL_FILE_PATH>		--> Restore single file"
        echo "restore: 	cat <BACKUP_FILE>.tar.gz-* | tar xvz -strip-components 3	--> Restore Files from 3 level deep path into current folder."
        echo ""
  }

function help-backup () {
          echo ""
          echo -e "${GOOD} IMAGE NAME MUST BE SUROUNDED BY \" \" IF THERE IS MORE THAN ONE WORD"
          echo "usage: ${NAME} --path ${HOME} -name \"home dir scripts\" OR home_dir_scripts "
          echo ""
          echo -e "${GOOD} BASIC BACKUP SPECIFY PATH, NAME FOR IMAGE AND TARGET LOCATION"
          echo -e "${GOOD} DEPENDING ON CONFIGURATION IT WILL KEEP LOCAL AS WELL AS CLOUD TARGET"
          echo "usage: 	${NAME} [--path <path> -name <name>] [-local|-mega |-nextcloud]"
          echo ""
          echo -e "${GOOD} FULL BACKUP OF SPECIFIC PATH, NAME FOR IMAGE AND TARGET LOCATION"
          echo "usage: 	${NAME} [--path <path> -name <name>] [-local|-mega |-nextcloud] [-full]"
          echo ""
          echo -e "${GOOD} BASIC BACKUP SPECIFY PATH, NAME FOR IMAGE AND TARGET LOCATION IN VERBOSE MODE"
          echo "usage: 	${NAME} [--path <path> -name <name>] [-local|-mega |-nextcloud] [-verbose]"
          echo ""
          echo -e "${GOOD} FULL BACKUP OF SPECIFIC PATH, NAME FOR IMAGE AND TARGET LOCATION IN VERBOSE MODE"
          echo "usage: 	${NAME} [--path <path> -name <name>] [-local|-mega |-nextcloud] [-full] [-verbose]"
          echo ""
          echo -e "${GOOD} BASIC BACKUP SPECIFING INCLUDE LIST, NAME FOR IMAGE AND TARGET LOCATION"
          echo "usage: 	${NAME} [--include <path-to-include-list> -name <name>] [-local|-mega |-nextcloud]"
          echo ""
          echo -e "${GOOD} BASIC BACKUP SPECIFING INCLUDE LIST, NAME FOR IMAGE AND TARGET LOCATION IN VERBOSE MODE"
          echo "usage: 	${NAME} [--include <path-to-include-list> -name <name>] [-local|-mega |-nextcloud] [-verbose]"
          echo ""
  }

function help-database () {
          echo ""
          echo -e "${GOOD} IMPORT MYSQL OR MARIADB FROM RETRIEVED BACKUP IMAGE"
          echo "usage: mysql -u username -p databasename -P < database_dump_image.sql"
          echo ""
          echo -e "${GOOD} IMPORT POSTGRESQL FROM RETRIEVED BACKUP IMAGE"
          echo "usage: psql -h hostname -d databasename -U username -f database_dump_image.sql"
          echo ""
  }

function help-cloud (){
          echo ""
          echo -e "${GOOD} NOTE: MEGA.nz FREE has a transfer limitation of 3GB per day / per IP address!"
          echo ""
          echo -e "${GOOD} NOTE: For MEGA.nz you required megacmd installed go to https://mega.nz/linux/MEGAsync/"
          echo "usage: sudo apt update && sudo apt upgrade && sudo apt install ./megacmd-package-name.deb"
          echo "usage: sudo dnf update && sudo dnf install ./megacmd-package-name.rpm"
          echo ""
          echo -e "${GOOD} NOTE: cadaver for Nextcloud requires a config file ~/.netrc but smalltarbkp will sort that out!"
          echo ""
          echo -e "${GOOD} NOTE: To install cadaver for Nextcloud on either Debian or Fedora based systems"
          echo "usage: sudo apt update && sudo apt upgrade && sudo apt install cadaver"
          echo "usage: sudo dnf update && sudo dnf install cadaver"
          echo ""
  }

function test_mega (){
          echo ""
          /usr/bin/mega-logout >/dev/null 2>&1 # Disconnect if connection already exist
          /usr/bin/mega-login ${mega_user_email} ${mega_user_password} >/dev/null 2>&1
          /usr/bin/mega-session >/dev/null 2>&1
  }

function netrc_tmp (){
          NETRC="${HOME}/.netrc"
          MACHINE=`echo "${NEXTCLOUD_URL}" | awk -F/ '{print $3}' | awk -F: '{print $1}'`
          LOGIN="${NEXTCLOUD_LOGIN}"
          PASS="${NEXTCLOUD_PASS}"

          if [[ -f ${NETRC} ]]; then
                  cp ${NETRC} "${NETRC}.$$"
          fi
          echo "machine ${MACHINE}" > ${NETRC}
          echo "login ${LOGIN}" >> ${NETRC}
          echo "password ${PASS}" >> ${NETRC}
  }

function netrc_test (){
netrc_tmp;
function test {
/usr/bin/cadaver ${NEXTCLOUD_URL} << EOA
ls
exit
EOA
}
test | egrep '(empty|succeeded)' >/tmp/$$.$$ 2>&1
RESULT=$?
if [ ${RESULT} == "0" ]; then
        echo -e "${GOOD} \e[33mNEXTCLOUD connection was Successfully\033[0m"
	if grep "empty" /tmp/$$.$$; then
		nextcloud_create_main_folder;
	fi
else
        echo ""
        echo -e "${MISSING} NEXTCLOUD failed to establish connection!"
        netrc_remove;
        echo ""
        exit 1;
fi
}

function nextcloud_create_main_folder (){
netrc_tmp;
function create {
/usr/bin/cadaver ${NEXTCLOUD_URL} << EOA
mkcol ${TARGET}
exit
EOA
}
create | grep "succeeded" >/dev/null 2>&1
RESULT=$?
if [ ${RESULT} == "0" ]; then
        echo -e "${GOOD} \e[33mTARGET Creation was Successful\033[0m"
else
        echo ""
        echo -e "${MISSING} NEXTCLOUD failed to establish connection!"
        echo -e "${NEED} SETUP aborted until NEXTCLOUD issues are resolved or SETUP without NEXTCLOUD"
        netrc_remove;
        echo ""
        exit 1;
fi
}

function nextcloud_create_dest_folder (){
netrc_tmp;
function create {
/usr/bin/cadaver ${NEXTCLOUD_URL} << EOA
mkcol ${TARGET}/${DATE}
exit
EOA
}
create >/dev/null 2>&1
}


function netrc_remove (){
          NETRC="${HOME}/.netrc"
          if [[ -f ${NETRC}.$$ ]]; then
                  mv ${NETRC}.$$ ${NETRC}
          fi
}


 function setup-smalltarbkp (){
          echo ""
          banner;
          echo ""
          echo -e "${RULLER}"
          echo -e "\033[1;31m\t\tALL SETTINGS WILL BE OVERITTEN! ENTER CTRL-C TO CANCEL\033[0m"
          echo -e "${RULLER}"
          echo ""
          echo "THIS IS AN INTERACTIVE Q/A CONFIG MENU OVERRIDING WITH EACH ANSWER!"
          echo ""
          ##### TAR SIZE VARIABLE ###
          if [[ -z ${IMAGE_SIZE} ]]; then
                  IMAGE_SIZE="250"
                  TMP="true"
          fi
          printf "Q/A - Maximum size of each TAR file in MEGABYTES (${IMAGE_SIZE}): "
          read -r tar_size
          while ! [[ ${tar_size} =~ ^-?[0-9]+$ ]] || [[ ${tar_size} == "" ]]
          do
                  echo -en "${MISSING} ERROR: ${tar_size} is not a valid size!: "
                  read -r tar_size
          done
          if [[ ${TMP} == "true" ]]; then
                  echo "IMAGE_SIZE=\"${tar_size}\"" > ${CONFIG}
                  TMP="";
          else
                  sed -i "s/IMAGE_SIZE=\"${IMAGE_SIZE}\"/IMAGE_SIZE=\"${tar_size}\"/" ${CONFIG}
          fi

        ##### TARGET VARIABLE ###
        if [[ -z ${LOCAL_TARGET} ]]; then
                LOCAL_TARGET="/tmp/"
                TMP="true"
        fi
        printf "Q/A - Target location NFS Mount | USB | Folder (${LOCAL_TARGET}): "
        read -r srv_local
        while [[ ${srv_local} == "" ]] || [[ ! -d ${srv_local} ]] || [[ ! -w ${srv_local} ]]
        do
                echo -en "${MISSING} ERROR: \033[1;31m${srv_local}\033[0m does not exist or user has no permission to write to this folder!: "
  		read -r srv_local
        done
        if [[ ${TMP} == "true" ]]; then
                echo "LOCAL_TARGET=\"${srv_local}\"" >> ${CONFIG}
                TMP=""
        else
                sed -i "s+LOCAL_TARGET=\"${LOCAL_TARGET}\"+LOCAL_TARGET=\"${srv_local}\"+" ${CONFIG}
        fi

        ##### RETENTION VARIABLE ###
        if [[ -z ${RETENTION} ]]; then
                RETENTION="10"
                TMP="true"
        fi
	printf "Q/A - How many backup copies to keep before deleting (${RETENTION}): "
	read -r bkp_retention
	while ! [[ ${bkp_retention} =~ ^-?[0-9]+$ ]] || [[ ${bkp_retention} == "" ]]
		do
		echo -en "${MISSING} ${bkp_retention} is not a valid number of backups!: "
		read -r bkp_retention
	done
	if [[ ${TMP} == "true" ]]; then
		echo "RETENTION=\"${bkp_retention}\"" >> ${CONFIG}
                TMP=""
	else
		sed -i "s+RETENTION=\"${RETENTION}\"+RETENTION=\"${bkp_retention}\"+" ${CONFIG}
	fi
        RETENTION=${bkp_retention};

        #### FREQUENCY VARIABLE ###
        if [[ -z ${FULLFREQ} ]]; then
                FULLFREQ="10"
                TMP="true"
        fi
        printf "Q/A - How often would you like to run a full backup (${FULLFREQ}): "
	read -r bkp_frequency
	while ! [[ ${bkp_frequency} =~ ^-?[0-9]+$ ]] && [[ "${bkp_frequency}" -lt "${RETENTION}" ]]
	do
		echo -en "${MISSING} ${bkp_frequency} is not a valid frequency! "
		read -r bkp_frequency
	done
	while [[ "${bkp_frequency}" -gt "${RETENTION}" ]] || [[ ! ${bkp_frequency} =~ ^-?[0-9]+$ ]]
	do
		echo -en "${MISSING} Frequency needs to be less that Retentio ${RETENTION}! "
		read -r bkp_frequency
	done
		if [[ ${TMP} == "true" ]]; then
		echo "FULLFREQ=\"${bkp_frequency}\"" >> ${CONFIG}
                TMP=""
	else
		sed -i "s/FULLFREQ=\"${FULLFREQ}\"/FULLFREQ=\"${bkp_frequency}\"/" ${CONFIG}
	fi

        ##### ENCRYPTION VARIABLE ###
        echo -e "\e[33mFYI - Encryption can double the time to complete your backups!\e[0m"
        printf "Q/A - Do you want to Encrypt the backup files? YES/NO (YES): "
	read -r bkp_encrypt

        while [[ "${bkp_encrypt}" != "yes" && "${bkp_encrypt}" != "YES" && "${bkp_encrypt}" != "no" && "${bkp_encrypt}" != "NO" ]]
	do
		if [[ -z ${bkp_encrypt} ]]; then
			bkp_encrypt="null"
		fi

		echo -en "${MISSING} ${bkp_encrypt} is NOT a valid option!: "
		read -r bkp_encrypt
	done

	if [[ ${bkp_encrypt} == "YES" ]] || [[ ${bkp_encrypt} == "yes" ]] || [[ ${bkp_encrypt} == "y" ]]; then
		if [[ -z ${ENCRYPT} ]]; then
			echo "ENCRYPT=\"true\"" >> ${CONFIG}
		else
			sed -i "s/ENCRYPT=\"${ENCRYPT}\"/ENCRYPT=\""true\""/" ${CONFIG}
		fi
	elif [[ ${bkp_encrypt} == "NO" ]] || [[ ${bkp_encrypt} == "no" ]] || [[ ${bkp_encrypt} == "n" ]]; then
		if [[ -z ${ENCRYPT} ]]; then
			echo "ENCRYPT=\"false\"" >> ${CONFIG}
		else
			sed -i "s/ENCRYPT=\"${ENCRYPT}\"/ENCRYPT=\"false\"/" ${CONFIG}
		fi
	fi

	if [[ ${bkp_encrypt} == "YES" ]] || [[ ${bkp_encrypt} == "yes" ]] || [[ ${bkp_encrypt} == "y" ]]; then
		printf "Q/A - Enter Preferred Encryption Password (Example: A1b2C3d4): "
			read -r -s pass_crypt
			echo
			while [[ -z ${pass_crypt} ]]
			do
				echo -en "${MISSING} ERROR: Encryption Password can NOT be empty:  "
				read -r pass_crypt
				echo
			done
			if [[ -z ${ENCPASS} ]]; then
				echo "ENCPASS=\"${pass_crypt}\"" >> ${CONFIG}
			else
				sed -i "s+ENCPASS=\"${ENCPASS}\"+ENCPASS=\"${pass_crypt}\"+" ${CONFIG}
			fi
	else
		pass_crypt="none";
		if [[ -z ${ENCPASS} ]]; then
			echo "ENCPASS=\"${pass_crypt}\"" >> ${CONFIG}
		else
			sed -i "s+ENCPASS=\"${ENCPASS}\"+ENCPASS=\"${pass_crypt}\"+" ${CONFIG}
		fi
	fi

        ##### SUBFOLDER DIRECTORY ###
        if [[ -z ${TARGET} ]]; then
                TARGET="SMALLTARBKP"
                TMP="true"
        fi
	printf "Q/A - SubFolder Name for all backups (No Spaces/Slashes) (${TARGET}): "
	read -r srv_sub
        while ! [[ ${srv_sub} =~ ^[a-zA-Z]+$ ]] || [[ ${srv_sub} == "" ]]
        do
                echo -en "${MISSING} ERROR: SubFolder can not be empty and can on contain letters: "
                read -r srv_sub
        done
        if [[ ${TMP} == "true" ]]; then
                echo "TARGET=\"${srv_sub}\"" >> ${CONFIG}
                TMP="";
        else
                sed -i "s+TARGET=\"${TARGET}\"+TARGET=\"${srv_sub}\"+" ${CONFIG}
        fi

        #### MEGA.nz variables ####
        printf "Q/A - Do you want to upload backups to \033[1;31m\"MEGA.nz\"\033[0m (YES|NO): "
	read -r cloud_yes_no
        while [[ "${cloud_yes_no}" != "yes" && "${cloud_yes_no}" != "YES" && "${cloud_yes_no}" != "no" && "${cloud_yes_no}" != "NO" ]]
        do
                echo -en "${MISSING} ERROR: Invalid response (YES|NO): "
                read -r cloud_yes_no
        done
	if [[ ${cloud_yes_no} == yes ]] || [[ ${cloud_yes_no} == YES ]]; then
		cloud_yes_no="true"
                if [[ -z ${MEGA_TRUE} ]]; then
                        echo "MEGA_TRUE=\"${cloud_yes_no}\"" >> ${CONFIG}
                else
                        sed -i "s+MEGA_TRUE=\"${MEGA_TRUE}\"+MEGA_TRUE=\"${cloud_yes_no}\"+" ${CONFIG}
                fi
                if [ ! -f /usr/bin/mega-login ]; then
                        echo ""
                        echo -e "${MISSING}  MISSING: MEGACMD NOT INSTALLED! { REQUIRED FOR MEGA.nz UPLOADING BACKUPS! }"
                        echo -e "1) - Go to https://mega.nz/linux/MEGAsync/"
                        echo -e "2) - Download required package megacmd-{Ubuntu|Debian|Raspbian|Fedora}"
                        echo -e "3) - Installed downloaded packages "
                        echo -e "${MISSING}  SETUP aborted until MEGACMD installed or SETUP without MEGA.nz option"
                        echo ""
                        exit 0;
                else
                        echo -e "${GOOD} \e[33mCHECKED and MEGACMD INSTALLED\033[0m"
                        printf "Q/A - What is your \033[1;31m\"MEGA.nz\"\033[0m capacity? FREE Default (50): "
			read -r cloud_size
                        while ! [[ ${cloud_size} =~ ^-?[0-9]+$ ]]
                        do
                                echo -en "${MISSING} ${cloud_size} is not a valid size! "
                                read -r cloud_size
                        done
                        if [[ -z ${MEGA_SIZE} ]]; then
                                echo "MEGA_SIZE=\"${cloud_size}\"" >> ${CONFIG}
                        else
                                sed -i "s+MEGA_SIZE=\"${MEGA_SIZE}\"+MEGA_SIZE=\"${cloud_size}\"+" ${CONFIG}
                        fi

                        printf "Q/A - Whats is your \033[1;31m\"MEGA.nz\"\033[0m User Email: "
                        read -r mega_user_email
                        while ! [[ ${mega_user_email} == *"@"*"."* ]]
                        do
                                echo -en "${MISSING} ${mega_user_email} is does not look like a valid email! "
                                read -r mega_user_email
                        done
                        if [[ -z ${MEGA_EMAIL} ]]; then
                                echo "MEGA_EMAIL=\"${mega_user_email}\"" >> ${CONFIG}
                        else
                                sed -i "s+MEGA_EMAIL=\"${MEGA_EMAIL}\"+MEGA_EMAIL=\"${mega_user_email}\"+" ${CONFIG}
                        fi

                        printf "Q/A - Whats is your \033[1;31m\"MEGA.nz\"\033[0m User Password: "
                        read -r -s mega_user_password

                        test_mega;
                        RESULT=$?
                        while ! [[ ${RESULT} == "0" ]]
                        do
                                echo -en "${MISSING} \e[34m ERROR - Login failed: invalid Password: \e[0m "
                                read -r mega_user_password
                                test_mega;
                                RESULT=$?
                        done

                        if [ ${RESULT} == "0" ]; then
                                echo -e "${GOOD} \e[33mMEGACMD successfully tested connection\033[0m"
                                if [[ -z ${MEGA_PASSWORD} ]]; then
                                        echo "MEGA_PASSWORD=\"${mega_user_password}\"" >> ${CONFIG}
                                else
                                        sed -i "s+MEGA_PASSWORD=\"${MEGA_PASSWORD}\"+MEGA_PASSWORD=\"${mega_user_password}\"+" ${CONFIG}
                                fi
                        fi
                        printf "Q/A - Keep local backup after uploading to \033[1;31m\"MEGA.nz\"\033[0m (YES|NO): "
                        read -r twocopies
                        while [[ "${twocopies}" != "yes" && "${twocopies}" != "YES" && "${twocopies}" != "no" && "${twocopies}" != "NO" ]]
                        do
                                if [[ -z ${twocopies} ]]; then
                                        twocopies="null"
                                fi
                                echo -en "${MISSING} ERROR: ${twocopies} Invalid response (YES|NO): "
                                read -r twocopies

                        done

                        if [[ ${twocopies} == "YES" ]] || [[ ${twocopies} == "yes" ]]; then
                                if [[ -z ${MEGA_BOTH} ]]; then
                                        echo "MEGA_BOTH=\"true\"" >> ${CONFIG}
                                else
                                        sed -i "s/MEGA_BOTH=\"${MEGA_BOTH}\"/MEGA_BOTH=\""true\""/" ${CONFIG}
                                fi
                        elif [[ ${twocopies} == "NO" ]] || [[ ${twocopies} == "no" ]]; then
                                if [[ -z ${MEGA_BOTH} ]]; then
                                        echo "MEGA_BOTH=\"false\"" >> ${CONFIG}
                                else
                                        sed -i "s/MEGA_BOTH=\"${MEGA_BOTH}\"/MEGA_BOTH=\"false\"/" ${CONFIG}
                                fi
                        fi
                fi

	else
		cloud_yes_no="false"
                if [[ -z ${MEGA_TRUE} ]]; then
                        echo "MEGA_TRUE=\"${cloud_yes_no}\"" >> ${CONFIG}
                        echo "MEGA_SIZE=\"${cloud_yes_no}\"" >> ${CONFIG}
                        echo "MEGA_EMAIL=\"${cloud_yes_no}\"" >> ${CONFIG}
                        echo "MEGA_PASSWORD=\"${cloud_yes_no}\"" >> ${CONFIG}
                        echo "MEGA_BOTH=\"${cloud_yes_no}\"" >> ${CONFIG}
                else
                        sed -i "s+MEGA_TRUE=\"${MEGA_TRUE}\"+MEGA_TRUE=\"${cloud_yes_no}\"+" ${CONFIG}
                        sed -i "s+MEGA_SIZE=\"${MEGA_SIZE}\"+MEGA_SIZE=\"${cloud_yes_no}\"+" ${CONFIG}
                        sed -i "s+MEGA_EMAIL=\"${MEGA_EMAIL}\"+MEGA_EMAIL=\"${cloud_yes_no}\"+" ${CONFIG}
                        sed -i "s+MEGA_PASSWORD=\"${MEGA_PASSWORD}\"+MEGA_PASSWORD=\"${cloud_yes_no}\"+" ${CONFIG}
                        sed -i "s+MEGA_BOTH=\"${MEGA_BOTH}\"+MEGA_BOTH=\"${cloud_yes_no}\"+" ${CONFIG}
                fi
	fi


        #### Nextcloud variables ####
        printf "Q/A - Do you want to upload backups to \033[1;31m\"Nextcloud\"\033[0m Server (YES|NO): "
	read -r nextcloud_yes_no

        while [[ "${nextcloud_yes_no}" != "" && "${nextcloud_yes_no}" != "yes" && "${nextcloud_yes_no}" != "YES" && "${nextcloud_yes_no}" != "no" && "${nextcloud_yes_no}" != "NO" ]]
        do
                echo -en "${MISSING} ERROR: Invalid response (YES|NO): "
                read -r nextcloud_yes_no
        done

	if [[ ${nextcloud_yes_no} == yes ]] || [[ ${nextcloud_yes_no} == YES ]] || [[ ${nextcloud_yes_no} == y ]]; then
                nextcloud_yes_no="true"
                if [[ -z ${NEXTCLOUD_TRUE} ]]; then
                        echo "NEXTCLOUD_TRUE=\"${nextcloud_yes_no}\"" >> ${CONFIG}
                else
                        sed -i "s+NEXTCLOUD_TRUE=\"${NEXTCLOUD_TRUE}\"+NEXTCLOUD_TRUE=\"${nextcloud_yes_no}\"+" ${CONFIG}
                fi
                if [ ! -f /usr/bin/cadaver ]; then
                        echo ""
                        echo -e "${MISSING}  MISSING: CADAVER NOT INSTALLED! { REQUIRED FOR NEXTCLOUD UPLOADING BACKUPS! }"
                        echo ""
                        echo -e "~ sudo apt install cadaver on UBUNTU"
                        echo -e "~ sudo dnf install cadaver on FEDORA"
                        echo -e "~ sudo apt-get install cadaver on DEBIAN"
                        echo ""
                        echo -e "${MISSING}  SETUP ABORTED UNTIL PACKAGED INSTALLED, THEN RUN SETUP AGAIN"
                        echo ""
                        exit 0;
                else
                        echo -e "${GOOD} \e[33mCHECKED and CADAVER INSTALLED\033[0m"
                        printf "Q/A - Enter the \033[1;31m\"NEXTCLOUD\"\033[0m Server URL: "
                        read -r nextcloud_url
                        while ! [[ ${nextcloud_url} == "http"*"//"*"."* ]]
                        do
                                echo -en "${MISSING} ${nextcloud_url} does not look like a valid URL! "
                                read -r nextcloud_url
                        done
                        if [[ -z ${NEXTCLOUD_URL} ]]; then
                                echo "NEXTCLOUD_URL=\"${nextcloud_url}\"" >> ${CONFIG}
                        else
                                sed -i "s+NEXTCLOUD_URL=\"${NEXTCLOUD_URL}\"+NEXTCLOUD_URL=\"${nextcloud_url}\"+" ${CONFIG}
                        fi

                        printf "Q/A - Enter your \033[1;31m\"NEXTCLOUD\"\033[0m username: "
                        read -r nextcloud_login
                        while [[ ${nextcloud_login} == "" ]]
                        do
                                echo -en "${MISSING} Nextcloud requires username: "
                                read -r nextcloud_login
                        done
                        if [[ -z ${NEXTCLOUD_LOGIN} ]]; then
                                echo "NEXTCLOUD_LOGIN=\"${nextcloud_login}\"" >> ${CONFIG}
                        else
                                sed -i "s+NEXTCLOUD_LOGIN=\"${NEXTCLOUD_LOGIN}\"+NEXTCLOUD_LOGIN=\"${nextcloud_login}\"+" ${CONFIG}
                        fi

                        printf "Q/A - Enter your \033[1;31m\"NEXTCLOUD\"\033[0m password: "
                        read -r -s nextcloud_pass
                        while [[ ${nextcloud_pass} == "" ]]
                        do
                                echo -en "${MISSING} Nextcloud required password: "
                                read -r nextcloud_pass
                        done
                        if [[ -z ${NEXTCLOUD_PASS} ]]; then
                                echo "NEXTCLOUD_PASS=\"${nextcloud_pass}\"" >> ${CONFIG}
                        else
                                sed -i "s+NEXTCLOUD_PASS=\"${NEXTCLOUD_PASS}\"+NEXTCLOUD_PASS=\"${nextcloud_pass}\"+" ${CONFIG}
                        fi
                        echo ""
                        netrc_tmp;
                        netrc_test;
                        nextcloud_create_main_folder;
                        netrc_remove;

                        printf "Q/A - Keep local backup after uploading to \033[1;31m\"NEXTCLOUD\"\033[0m (YES|NO): "
                        read -r local_nextcloud
                        while [[ "${local_nextcloud}" != "yes" && "${local_nextcloud}" != "YES" && "${local_nextcloud}" != "no" && "${local_nextcloud}" != "NO" ]]
                        do
                                if [[ -z ${local_nextcloud} ]]; then
                                        local_nextcloud="null"
                                fi
                                echo -en "${MISSING} ERROR: ${local_nextcloud} Invalid response (YES|NO): "
                                read -r local_nextcloud

                        done

                        if [[ ${local_nextcloud} == "YES" ]] || [[ ${local_nextcloud} == "yes" ]]; then
                                if [[ -z ${NEXTCLOUD_BOTH} ]]; then
                                        echo "NEXTCLOUD_BOTH=\"true\"" >> ${CONFIG}
                                else
                                        sed -i "s/NEXTCLOUD_BOTH=\"${NEXTCLOUD_BOTH}\"/NEXTCLOUD_BOTH=\""true\""/" ${CONFIG}
                                fi
                        elif [[ ${local_nextcloud} == "NO" ]] || [[ ${local_nextcloud} == "no" ]]; then
                                if [[ -z ${NEXTCLOUD_BOTH} ]]; then
                                        echo "NEXTCLOUD_BOTH=\"false\"" >> ${CONFIG}
                                else
                                        sed -i "s/NEXTCLOUD_BOTH=\"${NEXTCLOUD_BOTH}\"/NEXTCLOUD_BOTH=\"false\"/" ${CONFIG}
                                fi
                        fi
                fi
        else
                nextcloud_yes_no="false"
                if [[ -z ${NEXTCLOUD_TRUE} ]]; then
                        echo "NEXTCLOUD_TRUE=\"${nextcloud_yes_no}\"" >> ${CONFIG}
                        echo "NEXTCLOUD_URL=\"${nextcloud_yes_no}\"" >> ${CONFIG}
                        echo "NEXTCLOUD_LOGIN=\"${nextcloud_yes_no}\"" >> ${CONFIG}
                        echo "NEXTCLOUD_PASS=\"${nextcloud_yes_no}\"" >> ${CONFIG}
                        echo "NEXTCLOUD_BOTH=\"${nextcloud_yes_no}\"" >> ${CONFIG}
                else
                        sed -i "s+NEXTCLOUD_TRUE=\"${NEXTCLOUD_TRUE}\"+NEXTCLOUD_TRUE=\"${nextcloud_yes_no}\"+" ${CONFIG}
                        sed -i "s+NEXTCLOUD_URL=\"${NEXTCLOUD_URL}\"+NEXTCLOUD_URL=\"${nextcloud_yes_no}\"+" ${CONFIG}
                        sed -i "s+NEXTCLOUD_LOGIN=\"${NEXTCLOUD_LOGIN}\"+NEXTCLOUD_LOGIN=\"${nextcloud_yes_no}\"+" ${CONFIG}
                        sed -i "s+NEXTCLOUD_PASS=\"${NEXTCLOUD_PASS}\"+NEXTCLOUD_PASS=\"${nextcloud_yes_no}\"+" ${CONFIG}
                        sed -i "s+NEXTCLOUD_BOTH=\"${NEXTCLOUD_BOTH}\"+NEXTCLOUD_BOTH=\"${nextcloud_yes_no}\"+" ${CONFIG}
                fi
        fi

        if [[ -z ${SETUP} ]]; then
                echo "SETUP=\"true\"" >> ${CONFIG}
        else
                sed -i "s+SETUP=\"${SETUP}\"+SETUP=\"true\"+" ${CONFIG}
        fi
} # END Setup

function upgrade () {
        ########### UPGRADE START ###########

        if [[ ! -x "/usr/bin/curl" ]] ; then
                CURL="false";
                echo ""
                echo -e "${MISSING}  MISSING: To run upgrade you require curl installed & internet access!"
                echo ""
                echo -e "${GOOD} For Debian base run the following command"
                echo -e "$ sudo apt install curl"
                echo -e "${GOOD} For Fedora run the following command"
                echo -e "$ sudo dnf install curl"
                echo ""
                check | tee -a ${ERROR}
                exit 1
        else
                CURL="true";
		echo "NOTE: ${DATE} - Create copy of current script ..." | tee -a ${ERROR}
                cp ${NAME} ${NAME}-`echo ${VERSION} | tr " " "_"`
        fi

        #### DOWNLOAD THE LATEST VERSION OF THE SCRIPT
        echo "NOTE: ${DATE} - Downloading ..." | tee -a ${ERROR}
        if [[ $CURL == 'true' ]]; then
                /usr/bin/curl -L ${URL} 2>/dev/null -o downloaded
                if [ $? != "0" ]; then
                        echo ""
                        echo -e "${MISSING} ${DATE} FAILED TO DOWNLOAD THE LATEST VERSION OF THE SCRIPT" | tee -a ${ERROR}
                        echo -e "${MISSING} ${DATE} CHECK INTERNET AND URL: ${URL}" | tee -a ${ERROR}
                        check | tee -a ${ERROR}
                        exit 1;
                fi
                sleep 3
        fi

        #### Copy updated script and replace original old version
        echo "NOTE: ${DATE} - Replacing ..." | tee -a ${ERROR}
        cp downloaded ${NAME}
        if [ $? != "0" ]; then
                echo ""
                echo -e "${MISSING} ${DATE} FAILED TO REPLACE OLD SCRIPT WITH NEW SCRIPT" | tee -a ${ERROR}
                echo -e "${MISSING} ${DATE} CHECK downloaded AND ${NAME}" | tee -a ${ERROR}
                check | tee -a ${ERROR}
                exit 1;
        fi

        #### Update permissions from new script
        echo "NOTE: ${DATE} - Permissions ..." | tee -a ${ERROR}
        chmod 755 ${NAME}
        if [ $? != "0" ]; then
                echo ""
                echo -e "${MISSING} ${DATE} FAILED TO UPDATE SMALLTARBKP Permissions!" | tee -a ${ERROR}
                echo -e "${MISSING} ${DATE} CHECK if downloaded IS THE SAME AS ${NAME}" | tee -a ${ERROR}
                check | tee -a ${ERROR}
                exit 1;
        fi

	echo "NOTE: ${DATE} - Deleting temp files ..." | tee -a ${ERROR}
	rm downloaded
        ########### UPGRADE END ###########
}

function details () {
        echo "version: $VERSION"
        echo ""
        banner;
        echo ""
        cat ${CONFIG}
        echo ""
}

function image_local_report () {
        echo -e "               LIST OF AVAILABLE BACKUP FILES STORED ON \033[1;31m\"LOCAL\"\033[0m SYSTEM."
        echo ""
        echo -e "\033[1;31mID DATE FILE SIZE\033[0m" | awk '{printf("%-20s %-13s %-70s %1s\n", $1, $2, $3, $4)}'

        find ${LOCAL_TARGET}/${TARGET}/* -type f -printf x >/dev/null 2>&1
        	if [ $? = "0" ]; then
        		COUNTTHIS=$(find ${LOCAL_TARGET}/${TARGET}/* -type f -printf x | wc -c)
        		if [[ "${COUNTTHIS}" -gt "0" ]]; then
                                ls -l ${LOCAL_TARGET}/${TARGET}/* | sed -n -e 's/^.*\(bkp-\)/\1/p' | tr "." " " | awk '{print $1}' | awk -F- '{print $4}' >/tmp/$$.001
                                if [[ ${TARGET} =~ .*/.* ]]; then
                                {
                                        find ${LOCAL_TARGET}/${TARGET}/* -type f | sort | sed -n -e "s/^.*\(${TARGET#*/}\)/\1/p" | tr "\/" " " | awk '{print $2, $3}' >/tmp/$$.002
                                } else {
                                        find ${LOCAL_TARGET}/${TARGET}/* -type f | sort | sed -n -e "s/^.*\(${TARGET}\)/\1/p" | tr "\/" " " | awk '{print $2, $3}' >/tmp/$$.002
                                }
                                fi
        			ls -lh ${LOCAL_TARGET}/${TARGET}/* | grep "bkp-" | awk '{print $5}' | sed 's/M/ MB/g' | sed 's/K/ KB/g' | sed 's/G/ GB/g' >/tmp/$$.003
                                ls -lk ${LOCAL_TARGET}/${TARGET}/* | grep "bkp-" | awk '{print $5}' >/tmp/$$.004
        			if [[ ! -z ${1} ]]; then
        				paste /tmp/$$.001 /tmp/$$.002 /tmp/$$.003 | grep ${1} | awk '{print $1, $2, $3, $4, $5}' | awk '{printf("%-13s %-13s %-70s %1s %1s\n", $1, $2, $3, $4, $5)}'
                                        paste /tmp/$$.001 /tmp/$$.002 /tmp/$$.003 /tmp/$$.004 | grep ${1} | awk '{print $6}' >/tmp/$$.005
        			else
        				paste /tmp/$$.001 /tmp/$$.002 /tmp/$$.003 | awk '{print $1, $2, $3, $4, $5}' | awk '{printf("%-13s %-13s %-70s %1s %1s\n", $1, $2, $3, $4, $5)}'
                                        paste /tmp/$$.001 /tmp/$$.002 /tmp/$$.003 /tmp/$$.004 | awk '{print $6}' >/tmp/$$.005
        			fi
        			printf -- '-%.0s' {1..105}; echo ""
        			echo ""
                                sizeCalc=`printf "%.3f" $(cat /tmp/$$.005 | awk '{s = s + $1} END{print s/1024000}')`
        			echo -e "Total selected images: $sizeCalc MB" | awk '{printf("%-3s %-3s %-19s %1s %0s\n", $1, $2, $3, $4, $5)}'
        			echo -e "Total backup size: $(find ${LOCAL_TARGET}/${TARGET}/* -print0 | du -h --files0-from=- --total -s|tail -1 | awk '{print $1}')" | \
        				sed 's/M/ MB/g' | sed 's/K/ KB/g' | sed 's/G/ GB/g' | awk '{printf("%-3s %-3s %-21s %1s %1s\n", $1, $2, $3, $4, $5)}'
        		fi
        	else
        		echo ""
        		printf -- '-%.0s' {1..105}; echo ""
        		echo ""
        	fi

        	echo -e "Total storage free: $(df -h ${LOCAL_TARGET} | grep -v Used | awk '{print $4}')" |sed 's/M/ MB/g' | sed 's/K/ KB/g' | sed 's/G/ GB/g' | \
        		awk '{printf("%-3s %-3s %-20s %1s %1s\n", $1, $2, $3, $4, $5)}'
        		echo ""
        		echo -e "\033[1;31mBACKUP PATH:\033[0m ${SVR}/${TARGET}/"
        	echo ""
        	rm -rf /tmp/$$.*
}

function image_local_retrieve () {
	echo -e "               LIST OF AVAILABLE BACKUP FILES STORED ON \033[1;31m\"LOCAL\"\033[0m SYSTEM."
        echo ""
        echo -e "\033[1;31mID DATE FILE SIZE\033[0m" | awk '{printf("%-20s %-13s %-70s %1s\n", $1, $2, $3, $4)}'

        find ${LOCAL_TARGET}/${TARGET}/* -type f -printf x >/dev/null 2>&1
        	if [ $? = "0" ]; then
        		COUNTTHIS=$(find ${LOCAL_TARGET}/${TARGET}/* -type f -printf x | wc -c)
        		if [[ "${COUNTTHIS}" -gt "0" ]]; then
                                ls -l ${LOCAL_TARGET}/${TARGET}/* | sed -n -e 's/^.*\(bkp-\)/\1/p' | tr "." " " | awk '{print $1}' | awk -F- '{print $4}' >/tmp/$$.001
                                if [[ ${TARGET} =~ .*/.* ]]; then
                                {
                                        find ${LOCAL_TARGET}/${TARGET}/* -type f | sort | sed -n -e "s/^.*\(${TARGET#*/}\)/\1/p" | tr "\/" " " | awk '{print $2, $3}' >/tmp/$$.002
                                } else {
                                        find ${LOCAL_TARGET}/${TARGET}/* -type f | sort | sed -n -e "s/^.*\(${TARGET}\)/\1/p" | tr "\/" " " | awk '{print $2, $3}' >/tmp/$$.002
                                }
                                fi
        			ls -lh ${LOCAL_TARGET}/${TARGET}/* | grep "bkp-" | awk '{print $5}' | sed 's/M/ MB/g' | sed 's/K/ KB/g' | sed 's/G/ GB/g' >/tmp/$$.003
                                ls -lk ${LOCAL_TARGET}/${TARGET}/* | grep "bkp-" | awk '{print $5}' >/tmp/$$.004
        			if [[ ! -z ${1} ]]; then
        				paste /tmp/$$.001 /tmp/$$.002 /tmp/$$.003 | grep ${1} | awk '{print $1, $2, $3, $4, $5}' | awk '{printf("%-13s %-13s %-70s %1s %1s\n", $1, $2, $3, $4, $5)}'
                                        paste /tmp/$$.001 /tmp/$$.002 /tmp/$$.003 /tmp/$$.004 | grep ${1} | awk '{print $6}' >/tmp/$$.005
        			else
        				paste /tmp/$$.001 /tmp/$$.002 /tmp/$$.003 | awk '{print $1, $2, $3, $4, $5}' | awk '{printf("%-13s %-13s %-70s %1s %1s\n", $1, $2, $3, $4, $5)}'
                                        paste /tmp/$$.001 /tmp/$$.002 /tmp/$$.003 /tmp/$$.004 | awk '{print $6}' >/tmp/$$.005
        			fi
        			printf -- '-%.0s' {1..105}; echo ""
        			echo ""
                                sizeCalc=`printf "%.3f" $(cat /tmp/$$.005 | awk '{s = s + $1} END{print s/1024000}')`
        			echo -e "Total selected images: $sizeCalc MB" | awk '{printf("%-3s %-3s %-19s %1s %0s\n", $1, $2, $3, $4, $5)}'
        			echo -e "Total backup size: $(find ${LOCAL_TARGET}/${TARGET}/* -print0 | du -h --files0-from=- --total -s|tail -1 | awk '{print $1}')" | \
        				sed 's/M/ MB/g' | sed 's/K/ KB/g' | sed 's/G/ GB/g' | awk '{printf("%-3s %-3s %-21s %1s %1s\n", $1, $2, $3, $4, $5)}'
        		fi
        	else
        		echo ""
        		printf -- '-%.0s' {1..115}; echo ""
        		echo ""
        	fi

		echo ""
		printf -- '-%.0s' {1..115}; echo ""
		echo -e "          SELECT UNIQUE \033[1;31m\"ID\"\033[0m AND ALL ASSOCIATED IMAGES WILL BE RETRIEVED"
		echo -e "        ALL IMAGES RETRIEVED WILL ALSO BE AUTOMATICALLY DECRYPTED LOCALLY IF ENCRYPTED"
		echo -e ""
		printf "Q/A - What is the unique image \033[1;31m\"ID\"\033[0m you wish to retrieve: "
	        read -r restore_image_id
	        echo -e ""
			      if [[ ${restore_image_id} == "q" ]] || [[ ${restore_image_id} == "Q" ]]; then
				      exit 0
			      elif [[ ${restore_image_id} == [a-z] ]] && [[ ${restore_image_id} != "q" ]]; then
				      echo -e "${MISSING} ${DATE} \033[1;31m\"Invalid image ID!\"\033[0m >>> Valid = [ Numeric ID ], [ * ], [ q ]" | tee -a ${ERROR}
				      echo -e ""
				      exit 0
			      else
					/usr/bin/ls -lR ${LOCAL_TARGET}/${TARGET}/*/*${restore_image_id}* >/dev/null 2>&1
				      	if [[ ! $? == "0" ]]; then
					      echo -e "${MISSING} ${DATE} Image ID provided does not exist, please start again!" | tee -a ${ERROR}
					      exit 1
				      	fi
			      fi
	       echo -e ""

	       printf "Q/A - Where would you like to store your retrieved images temporarily: "
	       read -r retore_folder
	       restore_folder=$(echo ${retore_folder}| tr '\\' '/')

	       if [[ ! -e ${restore_folder} ]]; then
		       printf "Q/A - Directory \"${restore_folder}\" does NOT exist would  you like to create it (YES|NO)?: "
		       read -r create_tmp_folder
		       if [[ ${create_tmp_folder} == yes ]] || [[ ${create_tmp_folder} == YES ]] ; then
			       mkdir -p ${restore_folder}
			       if [[ ! $? == "0" ]]; then
				       echo -e "${MISSING} ${DATE} Failed to create temporary folder (Potentially lack of permissions)" | tee -a ${ERROR}
				       exit 1
			       fi
		       fi
	       fi

	       echo -e ""
	       echo -e "NOTE: Starting to retrieve images depending on size this could take a while!"

	       /usr/bin/cp -v ${LOCAL_TARGET}/${TARGET}/*/*${restore_image_id}* ${restore_folder}/
		       if [[ ! $? == "0" ]]; then
			       echo -e "${MISSING} ${DATE} Failed to retrieve some or all files, check connection or disk space!" | tee -a ${ERROR}
			       exit 1
		       fi
		       echo -e ""

		       RESTORED=$(ls -1 ${restore_folder}/*${restore_image_id}* | head -1)
		       if [[ ${RESTORED}  =~ \.enc$ ]]; then
			       echo -e "NOTE: Starting to decrypt images depending on quantity this could take a while!"
			       start_decrypt ${restore_folder};
		       else
			       echo -e "${GOOD} Images not encrypted, checking files!"
			       echo -e ""
		       fi

		       post_decrypt ${restore_folder} ${restore_image_id};
		       echo ""

		       rm /tmp/$$.*
}

function image_mega_report () {
        echo ""
 	echo -e "LIST OF AVAILABLE BACKUP FILES STORED ON \033[1;31m\"MEGA.nz\"\033[0m CLOUD."
	echo ""
	echo -e "\033[1;31mID DATE FILE SIZE\033[0m" | awk '{printf("%-20s %-22s %-70s %1s\n", $1, $2, $3, $4)}'
	/usr/bin/mega-session >/dev/null 2>&1
        if [ ! $? = "0" ]; then
		/usr/bin/mega-login ${MEGA_EMAIL} ${MEGA_PASSWORD} >/dev/null 2>&1
                /usr/bin/mega-session >/dev/null 2>&1
                if [ ! $? = "0" ]; then
                        echo -e "${MISSING} ${DATE} Failed to connect to \033[1;31m\"MEGA.nz!\"\033[0m" | tee -a ${ERROR}
			exit 1;
		fi
	fi
		mega-ls -lR ${TARGET}/*/* | sed -n -e 's/^.*\(bkp-\)/\1/p' | tr "." " " | awk '{print $1}' | awk -F- '{print $4}' >/tmp/$$.001
		mega-ls -lR ${TARGET}/*/* | tr "\/" " " | tr "\(" " " | tr "\)" " " | awk '{print $4, $5, $6, $3}' | egrep -v 'Couldn|DATE|NAME' > /tmp/$$.002
                sizeCalc=''
		if [[ ! -z ${1} ]]; then
			paste /tmp/$$.001 /tmp/$$.002 | grep ${1} | awk '{print $1, $2, $3, $4, $5}' | awk '{printf("%-13s %-5s %-12s %-70s %5s\n", $1, $2, $3, $4, $5)}'
                        PART1=$(mega-du ${TARGET}/*/* | grep ${1} | awk '{print $2}' | awk '{s = s + $1} END{print s/1024000}')
                        sizeCalc=$(printf "%.3f" $PART1)
		else
			paste /tmp/$$.001 /tmp/$$.002 | awk '{print $1, $2, $3, $4, $5}' | awk '{printf("%-13s %-5s %-12s %-70s %5s\n", $1, $2, $3, $4, $5)}'
                        PART1=$(mega-du ${TARGET}/*/* | grep [0-9] | awk '{print $2}' | awk '{s = s + $1} END{print s/1024000}')
                        sizeCalc=$(printf "%.3f" $PART1)
		fi

		printf -- '-%.0s' {1..115}; echo ""
		echo -e ""
		echo -e "Total selected size: $sizeCalc MB" | awk '{printf("%-3s %-3s %-19s %1s %1s\n", $1, $2, $3, $4, $5)}'
		echo -e ""
		rm -rf /tmp/$$.001 /tmp/$$.002
}

function image_nextcloud_report () {
	netrc_tmp;
        echo ""
 	echo -e "LIST OF AVAILABLE BACKUP FILES STORED ON \033[1;31m\"NEXTCLOUD\"\033[0m CLOUD."
	echo ""
	echo -e "\033[1;31mID DATE FILE SIZE\033[0m" | awk '{printf("%-20s %-22s %-70s %1s\n", $1, $2, $3, $4)}'
function test {
/usr/bin/cadaver ${NEXTCLOUD_URL} << EOA
ls ${TARGET}
exit
EOA
}
test | grep Coll | awk '{print $2}' > /tmp/$$.001
function test2 {
/usr/bin/cadaver ${NEXTCLOUD_URL} << EOA
ls ${TARGET}/${1}
exit
EOA
}
test2 >> /tmp/$$.002

for x in `cat /tmp/$$.001`
do
test2 $x >> /tmp/$$.003
done

cat /tmp/$$.003 | egrep '(bkp)' | awk '{print $1, $2}' >>/tmp/$$.004
cat /tmp/$$.004 | egrep '(bkp)' | tr "-" " " | tr "." " " | awk '{print $4}'  >>/tmp/$$.005
for x in `cat /tmp/$$.005`
do
date +%Y-%m-%d -d @$x >>/tmp/$$.006
done
if [[ ! -z ${1} ]]; then
        paste /tmp/$$.005 /tmp/$$.006 /tmp/$$.004 | grep ${1} | awk '{print $1, $2, $3, $4}' | awk '{printf("%-13s %-22s %-70s %1s\n", $1, $2, $3, $4)}'
        PART1=$(cat /tmp/$$.004 | grep ${1} | awk '{print $2}' | awk '{s = s + $1} END{print s/1024000}')
        sizeCalc=$(printf "%.3f" $PART1)
else
        paste /tmp/$$.005 /tmp/$$.006 /tmp/$$.004 | awk '{print $1, $2, $3, $4}' | awk '{printf("%-13s %-22s %-70s %1s\n", $1, $2, $3, $4)}'
        PART1=$(cat /tmp/$$.004 | awk '{print $2}' | awk '{s = s + $1} END{print s/1024000}')
        sizeCalc=$(printf "%.3f" $PART1)
fi


echo ""
printf -- '-%.0s' {1..115}; echo ""
echo -e ""
echo -e "Total selected size: $sizeCalc MB" | awk '{printf("%-3s %-3s %-21s %1s %1s\n", $1, $2, $3, $4, $5)}'
echo -e ""

rm /tmp/$$.*
netrc_remove;
}

function image_nextcloud_retrive () {
	netrc_tmp;
        echo ""
        echo -e "LIST OF AVAILABLE BACKUP FILES STORED ON \033[1;31m\"NEXTCLOUD\"\033[0m CLOUD."
        echo ""
        echo -e "\033[1;31mID DATE FILE SIZE\033[0m" | awk '{printf("%-20s %-22s %-70s %1s\n", $1, $2, $3, $4)}'
function test {
/usr/bin/cadaver ${NEXTCLOUD_URL} << EOA
ls ${TARGET}
exit
EOA
}
test | grep Coll | awk '{print $2}' > /tmp/$$.001
function test2 {
/usr/bin/cadaver ${NEXTCLOUD_URL} << EOA
ls ${TARGET}/${1}
exit
EOA
}
test2 >> /tmp/$$.002

for x in `cat /tmp/$$.001`
do
test2 $x >> /tmp/$$.003
done

cat /tmp/$$.003 | egrep '(bkp)' | awk '{print $1, $2}' >>/tmp/$$.004
cat /tmp/$$.004 | egrep '(bkp)' | tr "-" " " | tr "." " " | awk '{print $4}'  >>/tmp/$$.005
for x in `cat /tmp/$$.005`
do
date +%Y-%m-%d -d @$x >>/tmp/$$.006
done
if [[ ! -z ${1} ]]; then
        paste /tmp/$$.005 /tmp/$$.006 /tmp/$$.004 | grep ${1} | awk '{print $1, $2, $3, $4}' | awk '{printf("%-13s %-22s %-70s %1s\n", $1, $2, $3, $4)}'
        paste /tmp/$$.005 /tmp/$$.006 /tmp/$$.004 | grep ${1} >> /tmp/$$.007
else
        paste /tmp/$$.005 /tmp/$$.006 /tmp/$$.004 | awk '{print $1, $2, $3, $4}' | awk '{printf("%-13s %-22s %-70s %1s\n", $1, $2, $3, $4)}'
        paste /tmp/$$.005 /tmp/$$.006 /tmp/$$.004 >> /tmp/$$.007
fi


echo ""
printf -- '-%.0s' {1..115}; echo ""
echo -e "          SELECT UNIQUE \033[1;31m\"ID\"\033[0m AND ALL ASSOCIATED IMAGES WILL BE RETRIEVED"
echo -e "        ALL IMAGES RETRIEVED WILL ALSO BE AUTOMATICALLY DECRYPTED LOCALLY IF ENCRYPTED"
echo -e ""
printf "Q/A - What is the unique image \033[1;31m\"ID\"\033[0m you wish to retrieve: "
read -r restore_image_id
echo -e ""

if [[ ${restore_image_id} == "q" ]] || [[ ${restore_image_id} == "Q" ]]; then
        exit 0
elif [[ ${restore_image_id} == [a-z] ]] && [[ ${restore_image_id} != "q" ]]; then
        echo -e "${MISSING} ${DATE} \033[1;31m\"Invalid image ID!\"\033[0m >>> Valid = [ Numeric ID ], [ * ], [ q ]" | tee -a ${ERROR}
        echo -e ""
        exit 0
else
        grep ${restore_image_id} /tmp/$$.004
        while [[ ! $? == "0" ]]
        do
                printf "Image ID provided does not exist, please try again: "
                read -r restore_image_id
                grep ${restore_image_id} /tmp/$$.004
        done

        cat /tmp/$$.007 | grep ${restore_image_id} | awk '{print $2,$3}' >> /tmp/$$.008
fi
echo -e ""
PART1=$(cat /tmp/$$.004 | grep ${restore_image_id} | awk '{print $2}' | awk '{s = s + $1} END{print s/1024000}')
sizeCalc=$(printf "%.3f" $PART1)
echo -e "Total selected size: $sizeCalc MB" | awk '{printf("%-3s %-3s %-21s %1s %1s\n", $1, $2, $3, $4, $5)}'
echo -e ""

printf "Q/A - Where would you like to store your retrieved images temporarily: "
read -r retore_folder
restore_folder=$(echo ${retore_folder}| tr '\\' '/')

if [[ ! -e ${restore_folder} ]]; then
        printf "Q/A - Directory \"${restore_folder}\" does NOT exist would  you like to create it (YES|NO)?: "
        read -r create_tmp_folder
        if [[ ${create_tmp_folder} == yes ]] || [[ ${create_tmp_folder} == YES ]] ; then
                mkdir -p ${restore_folder}
                if [[ ! $? == "0" ]]; then
                        echo -e "${MISSING} ${DATE} Failed to create temporary folder (Potentially lack of permissions)" | tee -a ${ERROR}
                        exit 1
                fi
        fi
fi

function nextcloud_restore {
/usr/bin/cadaver ${NEXTCLOUD_URL} << EOA
lcd ${1}
get ${TARGET}/${2}
exit
EOA
}
nextcloud_restore >> /dev/null

echo -e ""
echo -e "NOTE: Starting to retrieve images depending on size this could take a while!"
echo -e ""
for y in `cat /tmp/$$.008| tr " " "/"`
do
        nextcloud_restore ${retore_folder} ${y} >/tmp/$$.10 2>&1
        grep succeeded /tmp/$$.10
done

echo -e "waiting"
RESTORED=$(ls -1 ${restore_folder}/*${restore_image_id}* | head -1)
if [[ ${RESTORED}  =~ \.enc$ ]]; then
        echo -e "NOTE: Starting to decrypt images depending on quantity this could take a while!"
        start_decrypt ${restore_folder};
else
        echo -e "${GOOD} Images not encrypted, checking files!"
        echo -e ""
fi

post_decrypt ${restore_folder} ${restore_image_id};
echo ""

rm /tmp/$$.*
netrc_remove;
}

image_mega_retrieve () {
	echo ""
	echo -e "LIST OF AVAILABLE BACKUP FILES STORED ON \033[1;31m\"MEGA.nz\"\033[0m CLOUD."
	echo ""
	echo -e "\033[1;31mID DATE FILE SIZE\033[0m" | awk '{printf("%-20s %-22s %-70s %1s\n", $1, $2, $3, $4)}'
	/usr/bin/mega-session >/dev/null 2>&1
	if [ ! $? = "0" ]; then
		/usr/bin/mega-login ${MEGA_EMAIL} ${MEGA_PASSWORD} >/dev/null 2>&1
		/usr/bin/mega-session >/dev/null 2>&1
		if [ ! $? = "0" ]; then
			echo -e "${MISSING} ${DATE} Failed to connect to \033[1;31m\"MEGA.nz!\"\033[0m" | tee -a ${ERROR}
			exit 1;
		fi
	fi
		mega-ls -lR ${TARGET}/*/* | sed -n -e 's/^.*\(bkp-\)/\1/p' | tr "." " " | awk '{print $1}' | awk -F- '{print $4}' >/tmp/$$.001
		mega-ls -lR ${TARGET}/*/* | tr "\/" " " | tr "\(" " " | tr "\)" " " | awk '{print $4, $5, $6, $3}' | egrep -v 'Couldn|DATE|NAME' > /tmp/$$.002
		sizeCalc=''
		if [[ ! -z ${1} ]]; then
			paste /tmp/$$.001 /tmp/$$.002 | grep ${1} | awk '{print $1, $2, $3, $4, $5}' | awk '{printf("%-13s %-5s %-12s %-70s %5s\n", $1, $2, $3, $4, $5)}'
			PART1=$(mega-du ${TARGET}/*/* | grep ${1} | awk '{print $2}' | awk '{s = s + $1} END{print s/1024000}')
			sizeCalc=$(printf "%.3f" $PART1)
		else
			paste /tmp/$$.001 /tmp/$$.002 | awk '{print $1, $2, $3, $4, $5}' | awk '{printf("%-13s %-5s %-12s %-70s %5s\n", $1, $2, $3, $4, $5)}'
			PART1=$(mega-du ${TARGET}/*/* | grep [0-9] | awk '{print $2}' | awk '{s = s + $1} END{print s/1024000}')
			sizeCalc=$(printf "%.3f" $PART1)
		fi

		printf -- '-%.0s' {1..115}; echo ""
		echo -e ""
		echo -e "Total selected size: $sizeCalc MB" | awk '{printf("%-3s %-3s %-19s %1s %1s\n", $1, $2, $3, $4, $5)}'
		echo -e ""
		echo -e "          SELECT UNIQUE \033[1;31m\"ID\"\033[0m AND ALL ASSOCIATED IMAGES WILL BE RETRIEVED"
        	echo -e "        ALL IMAGES RETRIEVED WILL ALSO BE AUTOMATICALLY DECRYPTED LOCALLY"
       	echo -e ""
       	printf "Q/A - What is the unique image \033[1;31m\"ID\"\033[0m you wish to retrieve: "
       	read -r restore_image_id
       	echo -e ""
                       if [[ ${restore_image_id} == "q" ]] || [[ ${restore_image_id} == "Q" ]]; then
                               exit 0
                       elif [[ ${restore_image_id} == [a-z] ]] && [[ ${restore_image_id} != "q" ]]; then
                               echo -e "${MISSING} ${DATE} \033[1;31m\"Invalid image ID!\"\033[0m >>> Valid = [ Numeric ID ], [ * ], [ q ]" | tee -a ${ERROR}
                               echo -e ""
                               exit 0
                       else
       					/usr/bin/mega-ls -lR ${TARGET}/*/*${restore_image_id}*
                               if [[ ! $? == "0" ]]; then
                                       echo -e "${MISSING} ${DATE} Image ID provided does not exist, please start again!" | tee -a ${ERROR}
                                       exit 1
                               fi
                       fi
       	echo -e ""

       	printf "Q/A - Where would you like to store your retrieved images temporarily: "
       	read -r retore_folder
       	restore_folder=$(echo ${retore_folder}| tr '\\' '/')

       	if [[ ! -e ${restore_folder} ]]; then
       		printf "Q/A - Directory \"${restore_folder}\" does NOT exist would  you like to create it (YES|NO)?: "
       		read -r create_tmp_folder
       		if [[ ${create_tmp_folder} == yes ]] || [[ ${create_tmp_folder} == YES ]] ; then
       			mkdir -p ${restore_folder}
       			if [[ ! $? == "0" ]]; then
       				echo -e "${MISSING} ${DATE} Failed to create temporary folder (Potentially lack of permissions)" | tee -a ${ERROR}
       				exit 1
       			fi
       		fi
       	fi

       	echo -e ""
       	echo -e "NOTE: Starting to retrieve images depending on size this could take a while!"

       	/usr/bin/mega-get ${TARGET}/*/*${restore_image_id}* ${restore_folder}/
       		if [[ ! $? == "0" ]]; then
       			echo -e "${MISSING} ${DATE} Failed to download some or all files, check connection or disk space!" | tee -a ${ERROR}
       			exit 1
       		fi
		echo -e ""

		RESTORED=$(ls -1 ${restore_folder}/*${restore_image_id}* | head -1)
		if [[ ${RESTORED}  =~ \.enc$ ]]; then
		        echo -e "NOTE: Starting to decrypt images depending on quantity this could take a while!"
		        start_decrypt ${restore_folder};
		else
		        echo -e "${GOOD} Images not encrypted, checking files!"
		        echo -e ""
		fi

		post_decrypt ${restore_folder} ${restore_image_id};
		echo ""

		rm /tmp/$$.*
}

function start_decrypt () {
        for decrypt in `ls -1 ${1}/*.enc`
        do
        openssl aes-256-cbc -d -a -pbkdf2 -in ${decrypt} -out $(echo -n ${decrypt} | head -c-4) -pass pass:${ENCPASS}

                if [[ ! $? == "0" ]]; then
                        echo -e "${MISSING} ${DATE} Failed to decrypt ${decrypt}!" | tee -a ${ERROR}
                        echo -e "INFO: \033[1;31mAttempting legacy encryption method!\033[0m" | tee -a ${ERROR}
                        openssl enc -d -aes-256-cbc -in ${decrypt} -out $(echo -n ${decrypt} | head -c-4) -pass pass:${ENCPASS}
                        if [[ ! $? == "0" ]]; then
                                echo -e "${MISSING} ${DATE} Failed to decrypt ${decrypt}, check availble disk space!" | tee -a ${ERROR}
                        else
                                echo -e "${GOOD} INFO: Successfully decrypted using legacy method!"
                                rm -f ${decrypt}
                        fi
                else
                        echo -e "${GOOD} Decrypted ${decrypt}";
                        rm -f ${decrypt}
                fi
        done
}

function post_decrypt (){
        ls ${1}/*${2}* | grep "sql" >>/dev/null
        if [[ $? == "0" ]]; then
                echo ""
                echo -e "NOTE: Successfully retrieved all requested images, located in: ${1}"
                echo "file(s):"
                ls -1 ${1}/*${2}* | sed 's,//,/,g'
                echo ""
        else
                echo -e "NOTE: Successfully retrieved all requested images, located in: ${1}"
                echo ""
                echo "list: 		cat ${1}/*${2}* | tar tz" | sed 's,//,/,g'
                echo "restore: 	cat ${1}/*${2}* | tar xz" | sed 's,//,/,g'
                echo "search: 	cat ${1}/*${2}* | tar tz | grep <PATTERN>" | sed 's,//,/,g'
                echo "restore: 	cat ${1}/*${2}* | tar xz <FULL_FILE_PATH>" | sed 's,//,/,g'
                echo ""
        fi
}


function encrypt_image (){
        echo ""
        if [[ ${2} == "VERBOSE" ]]; then
                echo -e "${GOOD} NOTE: ${DATE} Starting to encrypt backup files" | tee -a ${ERROR}
        fi
        for FILES in `ls -1 ${1}*`
        do
                openssl aes-256-cbc -a -pbkdf2 -in $FILES -out $FILES.enc -pass pass:$ENCPASS
                if [ $? = "0" ]; then
                        if [[ ${2} == "VERBOSE" ]]; then
                                echo -e "${GOOD} NOTE: ${DATE} Successfully encrypted $FILES.enc"
                        fi
                        rm -rf $FILES
                else
                        echo -e "${MISSING} ${DATE} Failed to run /"openssl/" command" | tee -a ${ERROR}
                        exit 1
                fi
        done
        echo ""
}

function verbose_start () {
        echo -e "${GOOD} SMALLTARBKP STARTING BACKUPS on ${HOSTNAME}"
        echo -e "${GOOD} ${HOSTNAME} - ${DATE} Backing up ${SRCDIR}"
        echo -e "${GOOD} ${HOSTNAME} - ${DATE} Running \"${1}\" backup!"
        if [[ ${1} == "INC" ]];then
                echo -e "${GOOD} ${HOSTNAME} - ${DATE} SNAPSHOT ${SNF}"
        fi
        echo -e "${GOOD} ${HOSTNAME} - ${DATE} Backup Name ${NEWNAME}"
        echo -e "${GOOD} ${HOSTNAME} - ${DATE} Backup encryption: ${ENCRYPT}"
        echo ""
}
function verbose_end () {
        sleep 1
        LOCALBKPSPACE=$(df -h ${LOCAL_TARGET} | grep -v Used | awk '{print $4}')
        if [[ ${2} == "FILE" ]]; then
        	BKPSIZE=$(du -hcs ${1}* | tail -1 | awk '{print $1}')
        fi
        echo -e "${GOOD} NOTE: ${DATE} Backup Size: 				${BKPSIZE}"
        echo -e "${GOOD} NOTE: ${DATE} Available: Local Target Space:		${LOCALBKPSPACE}"
}

function duration () {
        sleep 1
        elapsed=${SECONDS}
        echo -e "${GOOD} NOTE: ${DATE} Duration : $(($elapsed / 3600)) hour(s), $((($elapsed / 60) - ($elapsed / 3600 * 60))) minute(s) and $(($elapsed % 60)) seconds."
        echo ""
}

function mk_target () {
        if [ -d "${LOCAL_TARGET}" ]; then
                if [ ! -d "$DESDIR" ]; then
                        mkdir -p ${DESDIR}
                fi
                if [ ! -d "$DESDIR" ]; then
                        echo -e "${MISSING} ${DATE} TARGET does not exist or you don't have permission to create directory: $DESDIR" | tee -a ${ERROR}
                        exit 1
                fi
        fi
}
function nextcloud_upload () {
        echo -e "${GOOD} ${DATE} Starting Nextcloud upload";
netrc_test;
nextcloud_create_dest_folder;
for x in `ls ${LOCAL_TARGET}/${TARGET}/${DATE}/${BKPFILE}*`
do
/usr/bin/cadaver ${NEXTCLOUD_URL} << ADD
cd ${TARGET}/${DATE}
put $x
exit
ADD
done

echo -e "${GOOD} NOTE: ${DATE} Completed uploading backups"
echo "";
if [[ ${1} == "verb" ]];then
        verbose_end ${DESDIR}/${BKPFILE} "FILE";
        duration;
fi
netrc_remove;
}

function backup_nextcloud_norm () {
        if [[ ${NEXTCLOUD_TRUE} == "true" ]];then
                netrc_tmp;
                if [[ ${1} == "full" ]]; then
                        if [[ ${2} == "verb" ]];then
                                verbose_start "FULL";
                                backup_local_full_verb "full"
                        else
                                backup_local_full "full"
                        fi
                else
                        if [[ ${2} == "verb" ]];then
                                verbose_start "INC";
                                backup_local_norm_verb "inc"
                        else
                                backup_local_norm "inc"
                        fi
                fi
                nextcloud_upload ${2};

        else
                echo -e "${MISSING} ${DATE} NEXTCLOUD NOT CONFIGURED IF YOU WISH TO USE IT - PLEASE RUN SETUP FIRST." | tee -a ${ERROR}
        fi
}

function test_local_backup () {
        ls ${LOCAL_TARGET}/${TARGET}/${DATE}/${BKPFILE}* | grep ${BKPFILE} >/dev/null 2>&1
        RESULT=$?
        if [ ${RESULT} == "0" ]; then
                echo -e "${GOOD} \e[33mBackup was Successful\033[0m"
        else
                echo -e "${MISSING} LOCAL Backup failed!"
                exit 1;
        fi
}

function test_mega_backup (){
	if [[ ${MEGA_BOTH} == "false" ]]; then
		/usr/bin/rm -rf ${LOCAL_TARGET}/${TARGET}/${DATE}/${BKPFILE}*
	fi
        /usr/bin/mega-session >/dev/null 2>&1
        if [ ! $? = "0" ]; then
                /usr/bin/mega-login ${MEGA_EMAIL} ${MEGA_PASSWORD}
                if [ ! $? = "0" ]; then
                        echo -e "ERROR LIV: ${DATE} Failed to connect to \033[1;31m\"MEGA.nz!\"\033[0m" | tee -a ${ERROR}
                        exit 1
                else
                        /usr/bin/mega-cd / # Insure we are at root
                        /usr/bin/mega-ls ${TARGET}/${DATE}/${BKPFILE}* >/dev/null 2>&1
                        RESULT=$?
                        if [ ${RESULT} == "0" ]; then
                                echo -e "${GOOD} \e[33mBackup was Successful\033[0m"
                        else
                                echo -e "${MISSING} MEGA Backup failed to upload!"
                                exit 1;
                        fi
                fi
        else
                /usr/bin/mega-cd / # Insure we are at root
                /usr/bin/mega-ls ${TARGET}/${DATE}/${BKPFILE}* >/dev/null 2>&1
                RESULT=$?
                if [ ${RESULT} == "0" ]; then
                        echo -e "${GOOD} \e[33mBackup was Successful\033[0m"
                else
                        echo -e "${MISSING} MEGA Backup failed to upload!"
                        exit 1;
                fi

        fi

}

function test_nextcloud_backup() {
if [[ ${NEXTCLOUD_BOTH} == "false" ]]; then
	/usr/bin/rm -rf ${LOCAL_TARGET}/${TARGET}/${DATE}/${BKPFILE}*
fi

netrc_tmp;
function testbkp {
/usr/bin/cadaver ${NEXTCLOUD_URL} << EOA
ls ${TARGET}/${DATE}/
exit
EOA
}
testbkp | grep ${BKPFILE} >/dev/null 2>&1
RESULT=$?
if [ ${RESULT} == "0" ]; then
        echo -e "${GOOD} \e[33mBackup was Successful\033[0m"
else
        echo -e "${MISSING} NEXTCLOUD Backup failed to upload!"
        exit 1;
fi
netrc_remove;
}

function backup_local_norm () {
        mk_target;
        if [[ ${1} == "full" ]];then
                BKPFILE=bkp-${HOSTNAME}-${NEWNAME}-${TIME}.full.tar.gz-
        else
                BKPFILE=bkp-${HOSTNAME}-${NEWNAME}-${TIME}.inc.tar.gz-
        fi
        tar -czp -g ${SNF} ${SRCDIR} | split -d -b ${IMAGE_SIZE}m - ${DESDIR}/${BKPFILE}
        if [[ ${ENCRYPT} == "true" ]];then
                encrypt_image ${DESDIR}/${BKPFILE};
        fi
}
function backup_local_norm_verb () {
        mk_target;
        if [[ ${1} == "full" ]];then
                BKPFILE=bkp-${HOSTNAME}-${NEWNAME}-${TIME}.full.tar.gz-
        else
                if [[ ${2}  == "local" ]];then
                        verbose_start "INC";
                fi
                BKPFILE=bkp-${HOSTNAME}-${NEWNAME}-${TIME}.inc.tar.gz-
        fi
        sleep 3;
        tar -cvzp -g ${SNF} ${SRCDIR} | split -d -b ${IMAGE_SIZE}m - ${DESDIR}/${BKPFILE}
        if [[ ${ENCRYPT} == "true" ]];then
                encrypt_image ${DESDIR}/${BKPFILE}  "VERBOSE";
        fi
        if [[ ${2}  == "local" ]];then
                verbose_end ${DESDIR}/${BKPFILE} "FILE";
                duration;
        fi
}
function backup_local_full () {
        mk_target;
        if [[ ${1} == "full" ]];then
                BKPFILE=bkp-${HOSTNAME}-${NEWNAME}-${TIME}.full.tar.gz-
        else
                BKPFILE=bkp-${HOSTNAME}-${NEWNAME}-${TIME}.inc.tar.gz-
        fi
        tar -czp ${SRCDIR} | split -d -b ${IMAGE_SIZE}m - ${DESDIR}/${BKPFILE}
        if [[ ${ENCRYPT} == "true" ]];then
                encrypt_image ${DESDIR}/${BKPFILE};
        fi
}
function backup_local_full_verb () {
        mk_target;
        if [[ ${1} == "full" ]];then
                if [[ ${2}  == "local" ]];then
                        verbose_start "FULL";
                fi
                BKPFILE=bkp-${HOSTNAME}-${NEWNAME}-${TIME}.full.tar.gz-
        else
                BKPFILE=bkp-${HOSTNAME}-${NEWNAME}-${TIME}.inc.tar.gz-
        fi
        sleep 3;
        tar -cvzp ${SRCDIR} | split -d -b ${IMAGE_SIZE}m - ${DESDIR}/${BKPFILE}
        if [[ ${ENCRYPT} == "true" ]];then
                encrypt_image ${DESDIR}/${BKPFILE} "VERBOSE";
        fi

        if [[ ${2}  == "local" ]];then
                verbose_end ${DESDIR}/${BKPFILE} "FILE";
                duration;
        fi
}

function include_backup () {
        mk_target;
        if [[ ${1} == "verb" ]];then
                BKPFILE=bkp-${HOSTNAME}-${NEWNAME}-${TIME}.list.tar.gz-
                INCLUDE=${2}
                while read LINE
                do
                        echo "INCLUDING: $LINE"
                done < ${INCLUDE}
                tar -czvp -T $INCLUDE | split -d -b ${SIZE}m - ${DESDIR}/${BKPFILE}
                if [ $? = "0" ]; then
                        if [[ ${ENCRYPT} == "true" ]];then
                                encrypt_image ${DESDIR}/${BKPFILE} "VERBOSE";
                        fi
                fi

                if [[ ${3}  == "-local" ]];then
                        verbose_end ${DESDIR}/${BKPFILE} "FILE";
                        duration;
                fi
                if [[ ${3}  == "-nextcloud" ]];then
                        nextcloud_upload ${1};
                fi
                if [[ ${3}  == "-mega" ]];then
                        mega_upload ${1};
                fi
        fi
        if [[ ${1} == "norm" ]];then
                BKPFILE=bkp-${HOSTNAME}-${NEWNAME}-${TIME}.list.tar.gz-
                INCLUDE=${2}
                while read LINE
                do
                        echo "INCLUDING: $LINE"
                done < ${INCLUDE}
                tar -czvp -T $INCLUDE | split -d -b ${SIZE}m - ${DESDIR}/${BKPFILE}
                if [ $? = "0" ]; then
                        if [[ ${ENCRYPT} == "true" ]];then
                                encrypt_image ${DESDIR}/${BKPFILE};
                        fi
                fi

                if [[ ${3}  == "-local" ]];then
                        verbose_end ${DESDIR}/${BKPFILE} "FILE";
                        duration;
                fi
                if [[ ${3}  == "-nextcloud" ]];then
                        nextcloud_upload ${1};
                fi
                if [[ ${3}  == "-mega" ]];then
                        mega_upload ${1};
                fi
        fi
}
function count_full_backups (){
        ls -1 ${LOCAL_TARGET}/${TARGET}/*/bkp-${HOSTNAME}-${NEWNAME}*full* >/dev/null 2>&1
        TEST=$?
        if [[ ${TEST} == "0" ]];then
                COUNT=$(ls -1 ${LOCAL_TARGET}/${TARGET}/*/bkp-${HOSTNAME}-${NEWNAME}*full* | sed 's:.*/::' | awk -F- '{print $4}' | sort -u | wc -l)
                echo "${COUNT}";
        else
                echo "0";
        fi
}
function count_inc_backups (){
        ls -1 ${LOCAL_TARGET}/${TARGET}/*/bkp-${HOSTNAME}-${NEWNAME}*inc* >/dev/null 2>&1
        TEST=$?
        if [[ ${TEST} == "0" ]];then
                COUNT=$(ls -1 ${LOCAL_TARGET}/${TARGET}/*/bkp-${HOSTNAME}-${NEWNAME}*inc* | sed 's:.*/::' | awk -F- '{print $4}' | sort -u | wc -l)
                echo "${COUNT}";
        else
                echo "0";
        fi
}

function since_last_full () {
        ls -1 ${LOCAL_TARGET}/${TARGET}/*/bkp-${HOSTNAME}-${NEWNAME}* >/dev/null 2>&1
        TEST=$?
        if [[ ${TEST} == "0" ]];then
                COUNT=$(ls ${LOCAL_TARGET}/${TARGET}/*/bkp-${HOSTNAME}-${NEWNAME}* | sed 's:.*/::' | awk -F- '{print $4}' | sort -u | sed '1!G;h;$!d' | sed '/full/Q' | wc -l)
                echo "${COUNT}";
        else
                echo "0";
        fi
}

function mega_target () {
        /usr/bin/mega-cd / # Insure we are at root
        /usr/bin/mega-ls ${TARGET}/${DATE} >/dev/null 2>&1
        if [ ! $? = "0" ]; then
                /usr/bin/mega-mkdir -p ${TARGET}/${DATE}
                if [ ! $? = "0" ]; then
                        echo -e "${MISSING} ${DATE} Failed to create directory on\033[1;31m\"MEGA.nz!\"\033[0m" | tee -a ${ERROR}
                        /usr/bin/mega-logout >/dev/null 2>&1 # Disconnect open connection
                        exit 1
                fi
        fi
}

function local_size (){
        echo "";
        sleep 1
        BKPSIZE=$(du -hcs ${LOCAL_TARGET}/${TARGET}/${DATE}/${BKPFILE}* | tail -1 | awk '{print $1}')
        echo -e "${GOOD} NOTE: ${DATE} Backup Size        : ${BKPSIZE}"
}

function mega_end() {
        local_size;
        mega_size;
        duration;
}

function mega_upload () {
        echo -e "${GOOD} ${DATE} Starting MEGA.nz upload";
        echo -e "${GOOD} ${DATE} UPLOADING BACKUP FILES TO MEGA.nz!"
        /usr/bin/mega-session >/dev/null 2>&1
        if [ ! $? = "0" ]; then
                /usr/bin/mega-login ${MEGA_EMAIL} ${MEGA_PASSWORD}
                if [ ! $? = "0" ]; then
                        echo -e "ERROR LIV: ${DATE} Failed to connect to \033[1;31m\"MEGA.nz!\"\033[0m" | tee -a ${ERROR}
                        exit 1
                else
                        /usr/bin/mega-cd / # Insure we are at root
                        /usr/bin/mega-put -c ${LOCAL_TARGET}/${TARGET}/${DATE}/${BKPFILE}* ${TARGET}/${DATE}/
                fi
        else
                /usr/bin/mega-cd / # Insure we are at root
                /usr/bin/mega-put -c ${LOCAL_TARGET}/${TARGET}/${DATE}/${BKPFILE}* ${TARGET}/${DATE}/
        fi
        if [[ ${1} == "verb" || ${2} == "verb" ]]; then
                mega_end ${1};
        fi
}

function mega_size () {
	SIZEMUSED=$(/usr/bin/mega-du | awk '{print $4}')
        SIZECONVERT=$(expr ${MEGA_SIZE} \* 1024 \* 1024 \* 1024)
	SIZEREDUCED=$(expr ${SIZECONVERT} - ${SIZEMUSED})
    	echo -e "${GOOD} MEGA.nz Utilised : $(/usr/bin/numfmt --to=iec-i --suffix=B --padding=7 ${SIZEMUSED})"| awk '{printf("%-4s %0s %0s %19s %1s \n", $1, $2, $3, $4, $5)}'
	echo -e "${GOOD} MEGA.nz Available : $(/usr/bin/numfmt --to=iec-i --suffix=B --padding=7 ${SIZEREDUCED})"| awk '{printf("%-4s %0s %0s %18s %1s \n", $1, $2, $3, $4, $5)}'
}

function backup_mega (){
        if [[ ${MEGA_TRUE} == "true" ]];then
                mega_target;
                if [[ ${1} == "full" ]]; then
                        if [[ ${2} == "verb" ]];then
                                verbose_start "FULL";
                                backup_local_full_verb "full"
                        else
                                backup_local_full "full"
                        fi
                else
                        if [[ ${2} == "verb" ]];then
                                verbose_start "INC";
                                backup_local_norm_verb "inc"
                        else
                                backup_local_norm "inc"
                        fi
                fi
                if [[ ${2} == "verb" ]];then
                        mega_upload;
                        mega_size;
                        duration;
                else
                        mega_upload;
                fi
        else
                no_mega;
        fi
}

function no_mega () {
        echo ""
        echo -e "${MISSING} NO CLOUD BACKUPS CONFIGURED FOR \033[1;31m\"MEGA.nz\"\033[0m."
        echo ""
        exit 0
}

function mysql_backup() {
        mk_target;
        echo ""
        if [[ -x /usr/bin/mysqldump ]]; then
                echo -e "${GOOD} ${DATE} Starting to backup MYSQL database \033[1;31m\"${3}\"\033[0m" | tee -a ${ERROR}
                if [[ ${5}  == "-full" ]];then
                        BKPFILE=bkp-${DBHOST}-"mysql"-${TIME}.full.sql
                        /usr/bin/mysqldump --add-drop-database -c -h ${4} -u ${1} -p${2} ${3} | split -d -b ${IMAGE_SIZE}m - ${DESDIR}/${BKPFILE}
                        if [[ $? != "0" ]];then
                                echo -e "${MISSING} ${DATE} MYSQLDUMP FAILED POTENTIALLY WRONG CREDENTIALS" | tee -a ${ERROR}
                                echo ""
                                exit 1;
                        else
                                if [[ ${ENCRYPT} == "true" ]];then
                                        encrypt_image ${DESDIR}/${BKPFILE}  "VERBOSE";
                                fi
                                if [[ ${6} == "-nextcloud" ]]; then
                                        nextcloud_upload;
                                elif [[ ${6} == "-mega" ]];then
                                        mega_upload;
                                fi
                                echo -e "${GOOD} ${DATE} MySQL Full Backup completed"
                        fi
                elif [[ ${5} == "-data" ]];then
                        BKPFILE=bkp-${DBHOST}-"mysql"-${TIME}.data.sql
                        /usr/bin/mysqldump --no-create-info -c -h ${4} -u ${1} -p${2} ${3} | split -d -b ${IMAGE_SIZE}m - ${DESDIR}/${BKPFILE}
                        if [[ $? != "0" ]];then
                                echo -e "${MISSING} ${DATE} MYSQLDUMP FAILED POTENTIALLY WRONG CREDENTIALS" | tee -a ${ERROR}
                                echo ""
                                exit 1;
                        else
                                if [[ ${ENCRYPT} == "true" ]];then
                                        encrypt_image ${DESDIR}/${BKPFILE}  "VERBOSE";
                                fi
                                if [[ ${6} == "-nextcloud" ]]; then
                                        nextcloud_upload;
                                elif [[ ${6} == "-mega" ]];then
                                        mega_upload;
                                fi
                                echo -e "${GOOD} ${DATE} MySQL Data Backup completed"
                        fi
                elif [[ ${5} == "-schema" ]];then
                        BKPFILE=bkp-${DBHOST}-"mysql"-${TIME}.schema.sql
                        /usr/bin/mysqldump --no-data -c -h ${4} -u ${1} -p${2} ${3} | split -d -b ${IMAGE_SIZE}m - ${DESDIR}/${BKPFILE}
                        if [[ $? != "0" ]];then
                                echo -e "${MISSING} ${DATE} MYSQLDUMP FAILED POTENTIALLY WRONG CREDENTIALS" | tee -a ${ERROR}
                                echo ""
                                exit 1;
                        else
                                if [[ ${ENCRYPT} == "true" ]];then
                                        encrypt_image ${DESDIR}/${BKPFILE}  "VERBOSE";
                                fi
                                if [[ ${6} == "-nextcloud" ]]; then
                                        nextcloud_upload;
                                elif [[ ${6} == "-mega" ]];then
                                        mega_upload;
                                fi
                                echo -e "${GOOD} ${DATE} MySQL Schema Backup completed"
                        fi
                fi

        else
                echo -e "${MISSING} ${DATE} MYSQLDUMP DOES NOT SEEM TO BE INSTALLED LOCALLY" | tee -a ${ERROR}
                exit 1;
        fi
}

function postgres_backup () {
        mk_target;
        echo ""
        if [[ -x /usr/bin/pg_dump ]]; then
                echo -e "${GOOD} ${DATE} Starting to backup PostgreSQL database \033[1;31m\"${3}\"\033[0m" | tee -a ${ERROR}
                if [[ ${5}  == "-full" ]];then
                        BKPFILE=bkp-${DBHOST}-"psql"-${TIME}.full.sql
                        PGPASSWORD=${2} /usr/bin/pg_dump -h ${4} -d ${3} -U ${1} | split -d -b ${IMAGE_SIZE}m - ${DESDIR}/${BKPFILE}
                        if [[ $? != "0" ]];then
                                echo -e "${MISSING} ${DATE} PostgreSQL FAILED POTENTIALLY WRONG CREDENTIALS" | tee -a ${ERROR}
                                echo ""
                                exit 1;
                        else
                                if [[ ${ENCRYPT} == "true" ]];then
                                        encrypt_image ${DESDIR}/${BKPFILE}  "VERBOSE";
                                fi
                                if [[ ${6} == "-nextcloud" ]]; then
                                        nextcloud_upload;
                                elif [[ ${6} == "-mega" ]];then
                                        mega_upload;
                                fi
                                echo -e "${GOOD} ${DATE} PostgreSQL Full Backup completed"
                        fi
                elif [[ ${5} == "-data" ]];then
                        BKPFILE=bkp-${DBHOST}-"psql"-${TIME}.data.sql
                        PGPASSWORD=${2} /usr/bin/pg_dump --column-inserts --data-only -h ${4} -d ${3} -U ${1} | split -d -b ${IMAGE_SIZE}m - ${DESDIR}/${BKPFILE}
                        if [[ $? != "0" ]];then
                                echo -e "${MISSING} ${DATE} PostgreSQL FAILED POTENTIALLY WRONG CREDENTIALS" | tee -a ${ERROR}
                                echo ""
                                exit 1;
                        else
                                if [[ ${ENCRYPT} == "true" ]];then
                                        encrypt_image ${DESDIR}/${BKPFILE}  "VERBOSE";
                                fi
                                if [[ ${6} == "-nextcloud" ]]; then
                                        nextcloud_upload;
                                elif [[ ${6} == "-mega" ]];then
                                        mega_upload;
                                fi
                                echo -e "${GOOD} ${DATE} PostgreSQL Data Backup completed"
                        fi
                elif [[ ${5} == "-schema" ]];then
                        BKPFILE=bkp-${DBHOST}-"psql"-${TIME}.schema.sql
                        PGPASSWORD=${2} /usr/bin/pg_dump --schema-only -h ${4} -d ${3} -U ${1} | split -d -b ${IMAGE_SIZE}m - ${DESDIR}/${BKPFILE}
                        if [[ $? != "0" ]];then
                                echo -e "${MISSING} ${DATE} PostgreSQL FAILED POTENTIALLY WRONG CREDENTIALS" | tee -a ${ERROR}
                                echo ""
                                exit 1;
                        else
                                if [[ ${ENCRYPT} == "true" ]];then
                                        encrypt_image ${DESDIR}/${BKPFILE}  "VERBOSE";
                                fi
                                if [[ ${6} == "-nextcloud" ]]; then
                                        nextcloud_upload;
                                elif [[ ${6} == "-mega" ]];then
                                        mega_upload;
                                fi
                                echo -e "${GOOD} ${DATE} PostgreSQL Schema Backup completed"
                        fi
                fi
        fi
}

function purge_nexcloud () {
	netrc_tmp;
	echo ""
	echo -e "LIST OF AVAILABLE BACKUP FILES STORED ON \033[1;31m\"NEXTCLOUD\"\033[0m CLOUD."
	echo ""
	echo -e "\033[1;31mID DATE FILE SIZE\033[0m" | awk '{printf("%-20s %-22s %-70s %1s\n", $1, $2, $3, $4)}'
function test {
/usr/bin/cadaver ${NEXTCLOUD_URL} << EOA
ls ${TARGET}
exit
EOA
}
test | grep Coll | awk '{print $2}' > /tmp/$$.001
function test2 {
/usr/bin/cadaver ${NEXTCLOUD_URL} << EOA
ls ${TARGET}/${1}
exit
EOA
}
test2 >> /tmp/$$.002

for x in `cat /tmp/$$.001`
do
test2 $x >> /tmp/$$.003
done

cat /tmp/$$.003 | egrep '(bkp)' | awk '{print $1, $2}' >>/tmp/$$.004
cat /tmp/$$.004 | egrep '(bkp)' | tr "-" " " | tr "." " " | awk '{print $4}'  >>/tmp/$$.005
for x in `cat /tmp/$$.005`
do
date +%Y-%m-%d -d @$x >>/tmp/$$.006
done
if [[ ! -z ${1} ]]; then
	paste /tmp/$$.005 /tmp/$$.006 /tmp/$$.004 | grep ${1} | awk '{print $1, $2, $3, $4}' | awk '{printf("%-13s %-22s %-70s %1s\n", $1, $2, $3, $4)}'
	paste /tmp/$$.005 /tmp/$$.006 /tmp/$$.004 | grep ${1} >> /tmp/$$.007
else
	paste /tmp/$$.005 /tmp/$$.006 /tmp/$$.004 | awk '{print $1, $2, $3, $4}' | awk '{printf("%-13s %-22s %-70s %1s\n", $1, $2, $3, $4)}'
	paste /tmp/$$.005 /tmp/$$.006 /tmp/$$.004 >> /tmp/$$.007
fi


echo ""
printf -- '-%.0s' {1..115}; echo ""
echo -e "          SELECT UNIQUE \033[1;31m\"ID\"\033[0m AND ALL ASSOCIATED IMAGES WILL BE DELETED"
echo -e ""
printf "Q/A - What is the unique image \033[1;31m\"ID\"\033[0m you wish to retrieve: "
read -r delete_image_id
echo -e ""

if [[ ${delete_image_id} == "q" ]] || [[ ${delete_image_id} == "Q" ]]; then
	exit 0
elif [[ ${delete_image_id} == [a-z] ]] && [[ ${delete_image_id} != "q" ]]; then
	echo -e "${MISSING} ${DATE} \033[1;31m\"Invalid image ID!\"\033[0m >>> Valid = [ Numeric ID ], [ * ], [ q ]" | tee -a ${ERROR}
	echo -e ""
	exit 0
else
	grep ${delete_image_id} /tmp/$$.004
	while [[ ! $? == "0" ]]
	do
		printf "Image ID provided does not exist, please try again: "
		read -r delete_image_id
		grep ${delete_image_id} /tmp/$$.004
	done

	cat /tmp/$$.007 | grep ${delete_image_id} | awk '{print $2,$3}' >> /tmp/$$.008
fi
echo -e ""
printf "Q/A - Are you sure you want to delete those files (YES|NO)?: "
read -r answer

if [[ ${answer} == yes ]] || [[ ${answer} == YES ]] ; then
	echo -e ""
	echo -e "NOTE: Starting to delete images depending on size this could take a while!"
	echo -e ""

for y in `cat /tmp/$$.008| tr " " "/"`
do
/usr/bin/cadaver ${NEXTCLOUD_URL} << EOA
delete ${TARGET}/${y}
exit
EOA
done | grep Deleting
fi
echo ""
rm /tmp/$$.*
netrc_remove;
}

function purge_local () {
	echo -e "               LIST OF AVAILABLE BACKUP FILES STORED ON \033[1;31m\"LOCAL\"\033[0m SYSTEM."
	echo ""
	echo -e "\033[1;31mID DATE FILE SIZE\033[0m" | awk '{printf("%-20s %-13s %-70s %1s\n", $1, $2, $3, $4)}'

	find ${LOCAL_TARGET}/${TARGET}/* -type f -printf x >/dev/null 2>&1
		if [ $? = "0" ]; then
			COUNTTHIS=$(find ${LOCAL_TARGET}/${TARGET}/* -type f -printf x | wc -c)
			if [[ "${COUNTTHIS}" -gt "0" ]]; then
				ls -l ${LOCAL_TARGET}/${TARGET}/* | sed -n -e 's/^.*\(bkp-\)/\1/p' | tr "." " " | awk '{print $1}' | awk -F- '{print $4}' >/tmp/$$.001
				if [[ ${TARGET} =~ .*/.* ]]; then
				{
					find ${LOCAL_TARGET}/${TARGET}/* -type f | sort | sed -n -e "s/^.*\(${TARGET#*/}\)/\1/p" | tr "\/" " " | awk '{print $2, $3}' >/tmp/$$.002
				} else {
					find ${LOCAL_TARGET}/${TARGET}/* -type f | sort | sed -n -e "s/^.*\(${TARGET}\)/\1/p" | tr "\/" " " | awk '{print $2, $3}' >/tmp/$$.002
				}
				fi
				ls -lh ${LOCAL_TARGET}/${TARGET}/* | grep "bkp-" | awk '{print $5}' | sed 's/M/ MB/g' | sed 's/K/ KB/g' | sed 's/G/ GB/g' >/tmp/$$.003
				ls -lk ${LOCAL_TARGET}/${TARGET}/* | grep "bkp-" | awk '{print $5}' >/tmp/$$.004
				if [[ ! -z ${1} ]]; then
					paste /tmp/$$.001 /tmp/$$.002 /tmp/$$.003 | grep ${1} | awk '{print $1, $2, $3, $4, $5}' | awk '{printf("%-13s %-13s %-70s %1s %1s\n", $1, $2, $3, $4, $5)}'
					paste /tmp/$$.001 /tmp/$$.002 /tmp/$$.003 /tmp/$$.004 | grep ${1} | awk '{print $6}' >/tmp/$$.005
				else
					paste /tmp/$$.001 /tmp/$$.002 /tmp/$$.003 | awk '{print $1, $2, $3, $4, $5}' | awk '{printf("%-13s %-13s %-70s %1s %1s\n", $1, $2, $3, $4, $5)}'
					paste /tmp/$$.001 /tmp/$$.002 /tmp/$$.003 /tmp/$$.004 | awk '{print $6}' >/tmp/$$.005
				fi
				printf -- '-%.0s' {1..105}; echo ""
				echo ""
				sizeCalc=`printf "%.3f" $(cat /tmp/$$.005 | awk '{s = s + $1} END{print s/1024000}')`
				echo -e "Total selected images: $sizeCalc MB" | awk '{printf("%-3s %-3s %-19s %1s %0s\n", $1, $2, $3, $4, $5)}'
				echo -e "Total backup size: $(find ${LOCAL_TARGET}/${TARGET}/* -print0 | du -h --files0-from=- --total -s|tail -1 | awk '{print $1}')" | \
					sed 's/M/ MB/g' | sed 's/K/ KB/g' | sed 's/G/ GB/g' | awk '{printf("%-3s %-3s %-21s %1s %1s\n", $1, $2, $3, $4, $5)}'
			fi
		else
			echo ""
			printf -- '-%.0s' {1..115}; echo ""
			echo ""
		fi

		echo ""
		printf -- '-%.0s' {1..115}; echo ""
		echo -e "          SELECT UNIQUE \033[1;31m\"ID\"\033[0m AND ALL ASSOCIATED IMAGES WILL BE DELETED"
		echo -e ""
		printf "Q/A - What is the unique image \033[1;31m\"ID\"\033[0m you wish to delete: "
		read -r restore_image_id
		echo -e ""
			      if [[ ${restore_image_id} == "q" ]] || [[ ${restore_image_id} == "Q" ]]; then
				      exit 0
			      elif [[ ${restore_image_id} == [a-z] ]] && [[ ${restore_image_id} != "q" ]]; then
				      echo -e "${MISSING} ${DATE} \033[1;31m\"Invalid image ID!\"\033[0m >>> Valid = [ Numeric ID ], [ * ], [ q ]" | tee -a ${ERROR}
				      echo -e ""
				      exit 0
			      else
					/usr/bin/ls -lR ${LOCAL_TARGET}/${TARGET}/*/*${restore_image_id}* >/dev/null 2>&1
					if [[ ! $? == "0" ]]; then
					      echo -e "${MISSING} ${DATE} Image ID provided does not exist, please start again!" | tee -a ${ERROR}
					      exit 1
					fi
			      fi
	       echo -e ""
	       /usr/bin/ls -lR ${LOCAL_TARGET}/${TARGET}/*/*${restore_image_id}*
	       echo -e ""
	       printf "Q/A - Are you sure you want to delete those files (YES|NO)?: "
	       read -r answer
	       if [[ ${answer} == yes ]] || [[ ${answer} == YES ]] ; then
		       echo -e ""
		       echo -e "NOTE: Starting to delete images depending on size this could take a while!"
		       /usr/bin/rm -Rfv ${LOCAL_TARGET}/${TARGET}/*/*${restore_image_id}*
		       if [[ ! $? == "0" ]]; then
			       echo -e "${MISSING} ${DATE} Failed to delete some or all files!" | tee -a ${ERROR}
			       exit 1
		       fi
		       echo -e ""
		       rm /tmp/$$.*
	       	fi
}

function purge_mega() {
	echo ""
	echo -e "LIST OF AVAILABLE BACKUP FILES STORED ON \033[1;31m\"MEGA.nz\"\033[0m CLOUD."
	echo ""
	echo -e "\033[1;31mID DATE FILE SIZE\033[0m" | awk '{printf("%-20s %-22s %-70s %1s\n", $1, $2, $3, $4)}'
	/usr/bin/mega-session >/dev/null 2>&1
	if [ ! $? = "0" ]; then
		/usr/bin/mega-login ${MEGA_EMAIL} ${MEGA_PASSWORD} >/dev/null 2>&1
		/usr/bin/mega-session >/dev/null 2>&1
		if [ ! $? = "0" ]; then
			echo -e "${MISSING} ${DATE} Failed to connect to \033[1;31m\"MEGA.nz!\"\033[0m" | tee -a ${ERROR}
			exit 1;
		fi
	fi
		mega-ls -lR ${TARGET}/*/* | sed -n -e 's/^.*\(bkp-\)/\1/p' | tr "." " " | awk '{print $1}' | awk -F- '{print $4}' >/tmp/$$.001
		mega-ls -lR ${TARGET}/*/* | tr "\/" " " | tr "\(" " " | tr "\)" " " | awk '{print $4, $5, $6, $3}' | egrep -v 'Couldn|DATE|NAME' > /tmp/$$.002
		sizeCalc=''
		if [[ ! -z ${1} ]]; then
			paste /tmp/$$.001 /tmp/$$.002 | grep ${1} | awk '{print $1, $2, $3, $4, $5}' | awk '{printf("%-13s %-5s %-12s %-70s %5s\n", $1, $2, $3, $4, $5)}'
			PART1=$(mega-du ${TARGET}/*/* | grep ${1} | awk '{print $2}' | awk '{s = s + $1} END{print s/1024000}')
			sizeCalc=$(printf "%.3f" $PART1)
		else
			paste /tmp/$$.001 /tmp/$$.002 | awk '{print $1, $2, $3, $4, $5}' | awk '{printf("%-13s %-5s %-12s %-70s %5s\n", $1, $2, $3, $4, $5)}'
			PART1=$(mega-du ${TARGET}/*/* | grep [0-9] | awk '{print $2}' | awk '{s = s + $1} END{print s/1024000}')
			sizeCalc=$(printf "%.3f" $PART1)
		fi

	printf -- '-%.0s' {1..115}; echo ""
	echo -e ""
	echo -e "Total selected size: $sizeCalc MB" | awk '{printf("%-3s %-3s %-19s %1s %1s\n", $1, $2, $3, $4, $5)}'
	echo -e ""
	echo -e "          SELECT UNIQUE \033[1;31m\"ID\"\033[0m AND ALL ASSOCIATED IMAGES WILL BE DELETED"
       	echo -e "         THOSE IMAGES WILL NO LONGER BE AVAILABLE FOR RESTORE / RETRIEVE"
       	echo -e ""
       	printf "Q/A - What is the unique image \033[1;31m\"ID\"\033[0m you wish to delete: "
       	read -r delete_image_id
	echo -e ""
		       if [[ ${delete_image_id} == "q" ]] || [[ ${delete_image_id} == "Q" ]]; then
			       exit 0
		       elif [[ ${delete_image_id} == [a-z] ]] && [[ ${delete_image_id} != "q" ]]; then
			       echo -e "ERROR XXXVI: ${DATE} \033[1;31m\"Invalid image ID!\"\033[0m >>> Valid = [ Numeric ID ], [ * ], [ q ]" | tee -a ${ERROR}
			       echo -e ""
			       exit 0
		       else
			       mega-ls -lR ${TARGET}/*/*${delete_image_id}*
			       if [[ ! $? == "0" ]]; then
				       echo -e "ERROR XXXVII: ${DATE} Image ID provided does not exist, please start again!" | tee -a ${ERROR}
				       exit 1
			       fi
		       fi

	echo -e ""

	       if [[ ${delete_image_id} == "*" ]]; then
		       printf "Q/A - YOU HAVE SELECTED TO DELETE \033[1;31m\"ALL BACKUPS\"\033[0m continue? (YES|NO): "
		       read -r confirm_delete

	       else
		       printf "Q/A - DELETE all backups associated with \033[1;31m\"ID ${delete_image_id} \"\033[0m (YES|NO): "
		       read -r confirm_delete

	       fi

	       if [[ ${confirm_delete} == "yes" ]] || [[ ${confirm_delete} == "Yes" ]] || [[ ${confirm_delete} == "YES" ]] ; then
	echo -e "NOTE: Starting to delete images depending on size this could take a while!"
		       sleep 1
		       /usr/bin/mega-rm -rf ${TARGET}/*/*${delete_image_id}*
		       if [ $? = "0" ]; then
			       echo -e "NOTE: Successfully deleted all requested images!"
			       exit 0
		       else
			       echo -e "WARNING: One or more images failed to delete!"
			       echo ""
			       /usr/bin/mega-ls -lR ${TARGET}/*/*${delete_image_id}*
			       exit 1
		       fi

	       else
		       echo -e "Exiting... No images where deleted!"
		       exit 0
	       fi

	rm /tmp/$$.*
}

function purge_retention () {
#########################################################################
# CLEAN UP ALL CONFIGURED EXPIRED FILES
#########################################################################

for BKPDIRS in `find ${LOCAL_TARGET}/${TARGET}/ -maxdepth 1 -type d -mtime +$RETENTION`
do
	if [ $BKPDIRS != ${LOCAL_TARGET}/${TARGET}/ ]; then
       		/usr/bin/rm -rf $BKPDIRS
	fi
done

#########################################################################
# CLEAN UP MEGA EXPIRED FILES
#########################################################################

if [[ ${MEGA_TRUE} == "true" ]]; then
        COUNTFOLDERS=$(/usr/bin/mega-ls ${TARGET} | wc -l)
        COUNTFDIFF=$(expr ${COUNTFOLDERS} - ${RETENTION})

        if [ ${COUNTFOLDERS} -gt ${RETENTION} ]; then
                for delCF in `/usr/bin/mega-ls ${TARGET} | head -${COUNTFDIFF}`
                do
                        /usr/bin/mega-rm -rf ${TARGET}/$delCF
                done
        fi
fi

#########################################################################
# CLEAN UP NEXTCLOUD EXPIRED FILES
#########################################################################

if [[ ${NEXTCLOUD_TRUE} == "true" ]];then
netrc_tmp;

function folder {
/usr/bin/cadaver ${NEXTCLOUD_URL} << EOA
ls ${TARGET}
exit
EOA
}
folder | grep Coll | awk '{print $2}' > /tmp/$$.001

COUNTFOLDERS=$(cat /tmp/$$.001 | wc -l)
COUNTFDIFF=$(expr ${COUNTFOLDERS} - ${RETENTION})

if [ ${COUNTFOLDERS} -gt ${RETENTION} ]; then

function subfolder {
/usr/bin/cadaver ${NEXTCLOUD_URL} << EOA
ls ${TARGET}/${1}
exit
EOA
}
subfolder >> /tmp/$$.002

for x in `cat /tmp/$$.001 | head -${COUNTFDIFF}`
do
subfolder $x >> /tmp/$$.003
done

cat /tmp/$$.003 | egrep '(bkp)' | awk '{print $1, $2}' >>/tmp/$$.004
cat /tmp/$$.004 | egrep '(bkp)' | tr "-" " " | tr "." " " | awk '{print $4}'  >>/tmp/$$.005

for x in `cat /tmp/$$.005`
do
date +%Y-%m-%d -d @$x >>/tmp/$$.006
done

paste /tmp/$$.005 /tmp/$$.006 /tmp/$$.004 >> /tmp/$$.007
cat /tmp/$$.007 | awk '{print $2,$3}' >> /tmp/$$.008

for delFile in `cat /tmp/$$.008| tr " " "/"`
do
/usr/bin/cadaver ${NEXTCLOUD_URL} << EOA
delete ${TARGET}/${delFile}
exit
EOA
done | grep Deleting

for delFolder in `cat /tmp/$$.008 | awk '{print $1}' | sort -u`
do
/usr/bin/cadaver ${NEXTCLOUD_URL} << EOA
 rmcol ${TARGET}/${delFolder}
exit
EOA
done | grep Deleting

fi
fi #END

rm -rf /tmp/$$.*
netrc_remove;
}

# SELECT EXECUTABLE FUNCTION
if [[ -z ${1} ]]; then
        clear;
        help;
fi
if [[ ! -z ${1} ]] && [[ ${1} == "--help" ]] && [[ -z ${2} ]]; then
        clear;
        help;
elif [[ ! -z ${1} ]] && [[ ${1} == "--help" ]] && [[ ${2} == "report" ]]; then
        help-report;
elif [[ ! -z ${1} ]] && [[ ${1} == "--help" ]] && [[ ${2} == "restore" ]]; then
        help-restore;
elif [[ ! -z ${1} ]] && [[ ${1} == "--help" ]] && [[ ${2} == "backup" ]]; then
        help-backup;
elif [[ ! -z ${1} ]] && [[ ${1} == "--help" ]] && [[ ${2} == "db" ]]; then
        help-database;
elif [[ ! -z ${1} ]] && [[ ${1} == "--help" ]] && [[ ${2} == "cloud" ]]; then
        help-cloud;
elif [[ ! -z ${1} ]] && [[ ${1} == "--setup" ]] && [[ -z ${2} ]]; then
        clear;
        setup-smalltarbkp;
elif [[ ! -z ${1} ]] && [[ ${1} == "--check" ]] && [[ -z ${2} ]]; then
        clear;
        check;
elif [[ ! -z ${1} ]] && [[ ${1} == "--details" ]] && [[ -z ${2} ]]; then
        clear;
        details;
elif [[ ! -z ${1} ]] && [[ ${1} == "--upgrade" ]] && [[ -z ${2} ]]; then
        clear;
        upgrade;
elif [[ ${1} == "--images" ]] && [[ ${2} == "-local" ]] && [[ ${3} == "-report" ]] && [[ -z ${4} ]] && [[ ${MEGA_TRUE} == "true" ]]; then
        clear;
        image_local_report
elif [[ ${1} == "--images" ]] && [[ ${2} == "-local" ]] && [[ ${3} == "-report" ]] && [[ ${4} == "-s" ]] && [[ ! -z ${5} ]] && [[ ${MEGA_TRUE} == "true" ]]; then
        clear;
        image_local_report ${5}
elif [[ ${1} == "--images" ]] && [[ ${2} == "-local" ]] && [[ ${3} == "-retrieve" ]] && [[ -z ${4} ]] && [[ ${MEGA_TRUE} == "true" ]]; then
	clear;
	image_local_retrieve
elif [[ ${1} == "--images" ]] && [[ ${2} == "-local" ]] && [[ ${3} == "-retrieve" ]] && [[ ${4} == "-s" ]] && [[ ! -z ${5} ]] && [[ ${MEGA_TRUE} == "true" ]]; then
	clear;
	image_local_retrieve ${5}
elif [[ ${1} == "--images" ]] && [[ ${2} == "-mega" ]] && [[ ${3} == "-report" ]] && [[ -z ${4} ]] && [[ ${MEGA_TRUE} == "true" ]]; then
        clear;
        image_mega_report
elif [[ ${1} == "--images" ]] && [[ ${2} == "-mega" ]] && [[ ${3} == "-report" ]] && [[ ${4} == "-s" ]] && [[ ! -z ${5} ]] && [[ ${MEGA_TRUE} == "true" ]]; then
        clear;
        image_mega_report ${5}
elif [[ ${1} == "--images" ]] && [[ ${2} == "-mega" ]] && [[ ${3} == "-retrieve" ]] && [[ -z ${4} ]] && [[ ${MEGA_TRUE} == "true" ]]; then
	clear;
	image_mega_retrieve
elif [[ ${1} == "--images" ]] && [[ ${2} == "-mega" ]] && [[ ${3} == "-retrieve" ]] && [[ ${4} == "-s" ]] && [[ ! -z ${5} ]] && [[ ${MEGA_TRUE} == "true" ]]; then
	clear;
	image_mega_retrieve ${5}
elif [[ ${1} == "--images" ]] && [[ ${2} == "-nextcloud" ]] && [[ ${3} == "-report" ]] && [[ -z ${4} ]] && [[ ${NEXTCLOUD_TRUE} == "true" ]]; then
        clear;
        image_nextcloud_report
elif [[ ${1} == "--images" ]] && [[ ${2} == "-nextcloud" ]] && [[ ${3} == "-report" ]] && [[ ${4} == "-s" ]] && [[ ! -z ${5} ]] && [[ ${NEXTCLOUD_TRUE} == "true" ]]; then
        clear;
        image_nextcloud_report ${5}
# RETRIEVE
elif [[ ${1} == "--images" ]] && [[ ${2} == "-nextcloud" ]] && [[ ${3} == "-retrieve" ]] && [[ -z ${4} ]] && [[ ${NEXTCLOUD_TRUE} == "true" ]]; then
        clear;
        image_nextcloud_retrive
elif [[ ${1} == "--images" ]] && [[ ${2} == "-nextcloud" ]] && [[ ${3} == "-retrieve" ]] && [[ ${4} == "-s" ]] && [[ ! -z ${5} ]] && [[ ${NEXTCLOUD_TRUE} == "true" ]]; then
        clear;
        image_nextcloud_retrive ${5}
elif [[ ${1} == "--path" ]] && [[ ${3} == "-name" ]] && [[ ${5} == "-local" ]] && [[ -z ${6} ]]; then
        clear;
        ((INCCOUNT = $(since_last_full) + 1))
        if [[ ${INCCOUNT} -ge ${FULLFREQ} ]]; then
                backup_local_full "full" >/dev/null 2>&1
        else
                backup_local_norm "inc" >/dev/null 2>&1
        fi
        test_local_backup;
elif [[ ${1} == "--path" ]] && [[ ${3} == "-name" ]] && [[ ${5} == "-local" ]] && [[ ${6} == "-verbose" ]] && [[ -z ${7} ]]; then
        clear;
        ((INCCOUNT = $(since_last_full) + 1))
        if [[ ${INCCOUNT} -ge ${FULLFREQ} ]]; then
                backup_local_full_verb "full" "local"
        else
                backup_local_norm_verb "inc" "local"
        fi
elif [[ ${1} == "--path" ]] && [[ ${3} == "-name" ]] && [[ ${5} == "-local" ]] && [[ ${6} == "-full" ]] && [[ -z ${7} ]]; then
        clear;
        backup_local_full "full" >/dev/null 2>&1
elif [[ ${1} == "--path" ]] && [[ ${3} == "-name" ]] && [[ ${5} == "-local" ]] && [[ ${6} == "-full" ]] && [[ ${7} == "-verbose" ]] && [[ -z ${8} ]]; then
        clear;
        backup_local_full_verb "full"  "local";
elif [[ ${1} == "--path" ]] && [[ ${3} != "-name" ]]; then
        echo -e "${MISSING} ${DATE} SYNTAX ERROR PLEASE CHECK HELP!" | tee -a ${ERROR}
        help-backup;
elif [[ ${1} == "--path" ]] && [[ ${3} == "-name" ]] && [[ ${5} == "-nextcloud" ]] && [[ -z ${6} ]]; then
        clear;
        ((INCCOUNT = $(since_last_full) + 1))
        if [[ ${INCCOUNT} -ge ${FULLFREQ} ]]; then
                backup_nextcloud_norm "full"  >/dev/null 2>&1
        else
                backup_nextcloud_norm "inc"  >/dev/null 2>&1
        fi
        test_nextcloud_backup;
elif [[ ${1} == "--path" ]] && [[ ${3} == "-name" ]] && [[ ${5} == "-nextcloud" ]] && [[ ${6} == "-full" ]] && [[ -z ${7} ]]; then
        clear;
        backup_nextcloud_norm "full" "no" >/dev/null 2>&1
        test_nextcloud_backup;
elif [[ ${1} == "--path" ]] && [[ ${3} == "-name" ]] && [[ ${5} == "-nextcloud" ]] && [[ ${6} == "-verbose" ]] && [[ -z ${7} ]]; then
        clear;
        ((INCCOUNT = $(since_last_full) + 1))
        if [[ ${INCCOUNT} -ge ${FULLFREQ} ]]; then
                backup_nextcloud_norm "full" "verb"
        else
                backup_nextcloud_norm "inc" "verb"
        fi
        test_nextcloud_backup;
elif [[ ${1} == "--path" ]] && [[ ${3} == "-name" ]] && [[ ${5} == "-nextcloud" ]] && [[ ${6} == "-full" ]] && [[ ${7} == "-verbose" ]] && [[ -z ${8} ]]; then
        clear;
        backup_nextcloud_norm "full" "verb"
        test_nextcloud_backup;
elif [[ ${1} == "--path" ]] && [[ ${3} == "-name" ]] && [[ ${5} == "-mega" ]] && [[ -z ${6} ]]; then
        clear;
        ((INCCOUNT = $(since_last_full) + 1))
        if [[ ${INCCOUNT} -ge ${FULLFREQ} ]]; then
                backup_mega "full" "verb" >/dev/null 2>&1
        else
                backup_mega "inc" "verb" >/dev/null 2>&1
        fi
        test_mega_backup;
elif [[ ${1} == "--path" ]] && [[ ${3} == "-name" ]] && [[ ${5} == "-mega" ]] && [[ ${6} == "-full" ]] && [[ -z ${7} ]]; then
        clear;
        backup_mega "full" "no" >/dev/null 2>&1
        test_mega_backup;
elif [[ ${1} == "--path" ]] && [[ ${3} == "-name" ]] && [[ ${5} == "-mega" ]] && [[ ${6} == "-verbose" ]] && [[ -z ${7} ]]; then
        clear;
        ((INCCOUNT = $(since_last_full) + 1))
        if [[ ${INCCOUNT} -ge ${FULLFREQ} ]]; then
                backup_mega "full" "verb"
        else
                backup_mega "inc" "verb"
        fi
        test_mega_backup;
elif [[ ${1} == "--path" ]] && [[ ${3} == "-name" ]] && [[ ${5} == "-mega" ]] && [[ ${6} == "-full" ]] && [[ ${7} == "-verbose" ]] && [[ -z ${8} ]]; then
        clear;
        backup_mega "full" "verb"
        test_mega_backup;
elif [[ ${1} == "--path" ]] && [[ ${3} == "-name" ]] && ([[ ${5} != "-local" ]] || [[ ${5} != "-nextcloud" ]] || [[ ${5} != "-mega" ]]); then
        echo ""
        echo -e "${MISSING} Incorrect SYNTAX missing TARGET [-local|-mega |-nextcloud]";
        help-backup;
elif [[ ${1} == "--include" ]] && [[ ${3} == "-name" ]] && ([[ ${5} == "-local" ]] && [[ ${6} == "-verbose" ]] && [[ -z ${7} ]]); then
        clear;
        include_backup "verb" ${2} ${5};
        test_local_backup;
elif [[ ${1} == "--include" ]] && [[ ${3} == "-name" ]] && ([[ ${5} == "-nextcloud" ]] && [[ ${6} == "-verbose" ]] && [[ -z ${7} ]]); then
        clear;
        include_backup "verb" ${2} ${5};
        test_nextcloud_backup;
elif [[ ${1} == "--include" ]] && [[ ${3} == "-name" ]] && ([[ ${5} == "-mega" ]] && [[ ${6} == "-verbose" ]] && [[ -z ${7} ]]); then
        clear;
        include_backup "verb" ${2} ${5};
        test_mega_backup;
elif [[ ${1} == "--include" ]] && [[ ${3} == "-name" ]] && ([[ ${5} == "-local" ]] && [[ -z ${6} ]]); then
        clear;
        include_backup "norm" ${2} ${5}  >/dev/null 2>&1
        test_local_backup;
elif [[ ${1} == "--include" ]] && [[ ${3} == "-name" ]] && ([[ ${5} == "-nextcloud" ]] && [[ -z ${6} ]]); then
        clear;
        include_backup "norm" ${2} ${5}  >/dev/null 2>&1
        test_nextcloud_backup;
elif [[ ${1} == "--include" ]] && [[ ${3} == "-name" ]] && ([[ ${5} == "-mega" ]] && [[ -z ${6} ]]); then
        clear;
        include_backup "norm" ${2} ${5}  >/dev/null 2>&1
        test_mega_backup;
elif [[  ${1} == "--mysql" ]] && [[ ${2} == "-dbuser" ]] && [[ ${4} == "-dbpass" ]] && [[ ${6} == "-dbname" ]] && [[ ${8} == "-host" ]] && [[ ${10} == "-full" ]] && [[ ${11} == "-local" ]];then
        clear;
        mysql_backup ${3} ${5} ${7} ${9} ${10} ${11};
        local_size;
        duration;
        test_local_backup;
elif [[  ${1} == "--mysql" ]] && [[ ${2} == "-dbuser" ]] && [[ ${4} == "-dbpass" ]] && [[ ${6} == "-dbname" ]] && [[ ${8} == "-host" ]] && [[ ${10} == "-data" ]] && [[ ${11} == "-local" ]];then
        clear;
        mysql_backup ${3} ${5} ${7} ${9} ${10} ${11};
        local_size;
        duration;
        test_local_backup;
elif [[  ${1} == "--mysql" ]] && [[ ${2} == "-dbuser" ]] && [[ ${4} == "-dbpass" ]] && [[ ${6} == "-dbname" ]] && [[ ${8} == "-host" ]] && [[ ${10} == "-schema" ]] && [[ ${11} == "-local" ]];then
        clear;
        mysql_backup ${3} ${5} ${7} ${9} ${10} ${11};
        local_size;
        duration;
        test_local_backup;
elif [[  ${1} == "--mysql" ]] && [[ ${2} == "-dbuser" ]] && [[ ${4} == "-dbpass" ]] && [[ ${6} == "-dbname" ]] && [[ ${8} == "-host" ]] && [[ ${10} == "-full" ]] && [[ ${11} == "-nextcloud" ]];then
        clear;
        mysql_backup ${3} ${5} ${7} ${9} ${10} ${11};
        test_nextcloud_backup;
elif [[  ${1} == "--mysql" ]] && [[ ${2} == "-dbuser" ]] && [[ ${4} == "-dbpass" ]] && [[ ${6} == "-dbname" ]] && [[ ${8} == "-host" ]] && [[ ${10} == "-data" ]] && [[ ${11} == "-nextcloud" ]];then
        clear;
        mysql_backup ${3} ${5} ${7} ${9} ${10} ${11};
        test_nextcloud_backup;
elif [[  ${1} == "--mysql" ]] && [[ ${2} == "-dbuser" ]] && [[ ${4} == "-dbpass" ]] && [[ ${6} == "-dbname" ]] && [[ ${8} == "-host" ]] && [[ ${10} == "-schema" ]] && [[ ${11} == "-nextcloud" ]];then
        clear;
        mysql_backup ${3} ${5} ${7} ${9} ${10} ${11};
        test_nextcloud_backup;
elif [[  ${1} == "--mysql" ]] && [[ ${2} == "-dbuser" ]] && [[ ${4} == "-dbpass" ]] && [[ ${6} == "-dbname" ]] && [[ ${8} == "-host" ]] && [[ ${10} == "-full" ]] && [[ ${11} == "-mega" ]];then
        clear;
        mysql_backup ${3} ${5} ${7} ${9} ${10} ${11};
        test_mega_backup;
elif [[  ${1} == "--mysql" ]] && [[ ${2} == "-dbuser" ]] && [[ ${4} == "-dbpass" ]] && [[ ${6} == "-dbname" ]] && [[ ${8} == "-host" ]] && [[ ${10} == "-data" ]] && [[ ${11} == "-mega" ]];then
        clear;
        mysql_backup ${3} ${5} ${7} ${9} ${10} ${11};
        test_mega_backup;
elif [[  ${1} == "--mysql" ]] && [[ ${2} == "-dbuser" ]] && [[ ${4} == "-dbpass" ]] && [[ ${6} == "-dbname" ]] && [[ ${8} == "-host" ]] && [[ ${10} == "-schema" ]] && [[ ${11} == "-mega" ]];then
        clear;
        mysql_backup ${3} ${5} ${7} ${9} ${10} ${11};
        test_mega_backup;
elif [[  ${1} == "--psql" ]] && [[ ${2} == "-dbuser" ]] && [[ ${4} == "-dbpass" ]] && [[ ${6} == "-dbname" ]] && [[ ${8} == "-host" ]] && [[ ${10} == "-full" ]] && [[ ${11} == "-local" ]];then
        clear;
        postgres_backup ${3} ${5} ${7} ${9} ${10} ${11};
        local_size;
        duration;
        test_local_backup;
elif [[  ${1} == "--psql" ]] && [[ ${2} == "-dbuser" ]] && [[ ${4} == "-dbpass" ]] && [[ ${6} == "-dbname" ]] && [[ ${8} == "-host" ]] && [[ ${10} == "-data" ]] && [[ ${11} == "-local" ]];then
        clear;
        postgres_backup ${3} ${5} ${7} ${9} ${10} ${11};
        local_size;
        duration;
        test_local_backup;
elif [[  ${1} == "--psql" ]] && [[ ${2} == "-dbuser" ]] && [[ ${4} == "-dbpass" ]] && [[ ${6} == "-dbname" ]] && [[ ${8} == "-host" ]] && [[ ${10} == "-schema" ]] && [[ ${11} == "-local" ]];then
        clear;
        postgres_backup ${3} ${5} ${7} ${9} ${10} ${11};
        local_size;
        duration;
        test_local_backup;
elif [[  ${1} == "--psql" ]] && [[ ${2} == "-dbuser" ]] && [[ ${4} == "-dbpass" ]] && [[ ${6} == "-dbname" ]] && [[ ${8} == "-host" ]] && [[ ${10} == "-full" ]] && [[ ${11} == "-nextcloud" ]];then
        clear;
        postgres_backup ${3} ${5} ${7} ${9} ${10} ${11};
        duration;
        test_nextcloud_backup;
elif [[  ${1} == "--psql" ]] && [[ ${2} == "-dbuser" ]] && [[ ${4} == "-dbpass" ]] && [[ ${6} == "-dbname" ]] && [[ ${8} == "-host" ]] && [[ ${10} == "-data" ]] && [[ ${11} == "-nextcloud" ]];then
        clear;
        postgres_backup ${3} ${5} ${7} ${9} ${10} ${11};
        duration;
        test_nextcloud_backup;
elif [[  ${1} == "--psql" ]] && [[ ${2} == "-dbuser" ]] && [[ ${4} == "-dbpass" ]] && [[ ${6} == "-dbname" ]] && [[ ${8} == "-host" ]] && [[ ${10} == "-schema" ]] && [[ ${11} == "-nextcloud" ]];then
        clear;
        postgres_backup ${3} ${5} ${7} ${9} ${10} ${11};
        duration;
        test_nextcloud_backup;
elif [[  ${1} == "--psql" ]] && [[ ${2} == "-dbuser" ]] && [[ ${4} == "-dbpass" ]] && [[ ${6} == "-dbname" ]] && [[ ${8} == "-host" ]] && [[ ${10} == "-full" ]] && [[ ${11} == "-mega" ]];then
        clear;
        postgres_backup ${3} ${5} ${7} ${9} ${10} ${11};
        duration;
        test_mega_backup;
elif [[  ${1} == "--psql" ]] && [[ ${2} == "-dbuser" ]] && [[ ${4} == "-dbpass" ]] && [[ ${6} == "-dbname" ]] && [[ ${8} == "-host" ]] && [[ ${10} == "-data" ]] && [[ ${11} == "-mega" ]];then
        clear;
        postgres_backup ${3} ${5} ${7} ${9} ${10} ${11};
        duration;
        test_mega_backup;
elif [[  ${1} == "--psql" ]] && [[ ${2} == "-dbuser" ]] && [[ ${4} == "-dbpass" ]] && [[ ${6} == "-dbname" ]] && [[ ${8} == "-host" ]] && [[ ${10} == "-schema" ]] && [[ ${11} == "-mega" ]];then
        clear;
        postgres_backup ${3} ${5} ${7} ${9} ${10} ${11};
        duration;
        test_mega_backup;
elif [[ ${1} == "--purge-manually" ]] && [[ ${2} == "-local" ]]; then
	clear;
	purge_local;
elif [[ ${1} == "--purge-manually" ]] && [[ ${2} == "-nextcloud" ]]; then
	clear;
	purge_nexcloud;
elif [[ ${1} == "--purge-manually" ]] && [[ ${2} == "-mega" ]]; then
	clear;
	purge_mega;
elif [[ ${1} == "--purge-maintanance" ]] && [[ -z ${2} ]]; then
	clear;
	purge_retention;
fi
