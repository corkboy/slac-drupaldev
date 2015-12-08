#!/bin/sh
 
#-------------------------------------------------------------------------
#
# This script sets up a new local drupal site for you, taking parameters
# from the user:
#	1. desired site name* (e.g., my-test-site.local)
#	2. port number*  (port number for the site, e.g., http://mysite.local:8888)
#	2. github URL*  (for the repo for the drupal code-base)
#	3. special site identifier  (e.g., IGP, WWW6 - unique treatments for these)
#
# Author: Ray Horgan
# Date: 12/4/2015
#
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
# Catpure the script parameters
#-------------------------------------------------------------------------
SITE_NAME=$1
PORT_NUM=$2
REPO_URL=$3
SITE_PROFILE=$4
SPECIAL_SITE_ID=$5


# Read in the local config file for this script to work
source ./create-drupal-site.cfg

#-------------------------------------------------------------------------
# Script globals
#-------------------------------------------------------------------------
SITE_PATH=$SITES_DIR/$SITE_NAME 	# file path to the site on local system

#=========================================================================
#=========================================================================
#=========================================================================


#-------------------------------------------------------------------------
# FUNCTION ECHO_STEP
#-------------------------------------------------------------------------
function echo_step() {
	echo "\n............................................................................"
	echo "$1\n............................................................................"
}
#-------------------------------------------------------------------------
# FUNCTION CREATE_SITE_DIRECTORY
#-------------------------------------------------------------------------
function create_site_directory() 
{
	echo_step "Creating site directory: $SITE_PATH"
	mkdir -p $SITE_PATH
}
#-------------------------------------------------------------------------
# FUNCTION CLONE_REPO
#-------------------------------------------------------------------------
function clone_repo() 
{
	echo_step "Clone repo: $REPO_URL"
	git clone $REPO_URL $SITE_PATH
	cd $SITE_PATH
}
#-------------------------------------------------------------------------
# FUNCTION CONFIG_VHOST
#-------------------------------------------------------------------------
function config_vhost() {

	echo_step "Configuring Virtual Host for this site: http://$SITE_NAME:$PORT_NUM"
	VHOST_STR="NameVirtualHost *:$PORT_NUM\n\n
<VirtualHost *:8888>\n\t
   ServerAdmin $SERVER_ADMIN_EMAIL\n\t
   DocumentRoot $SITE_PATH\n\t
   ServerName $SITE_NAME$SITE_DOMAIN\n\t
   ServerAlias $SITE_NAME$SITE_DOMAIN\n\t
   ErrorLog \"logs/$SITE_NAME$SITE_DOMAIN-error_log\"\n\t
   CustomLog \"logs/$SITE_NAME$SITE_DOMAIN-access_log\" common\n
</VirtualHost>"

	echo $VHOST_STR > $VHOST_DIR/$VHOST_FILENAME

	echo_step "Restart apache to pick up new virtual host"
	$APACHE_RESTART_STR

}
#-------------------------------------------------------------------------
# FUNCTION ADD_LOCAL_SITE_DNS_ENTRY
#-------------------------------------------------------------------------
function add_local_site_dns_entry() 
{
	echo_step "Add local DNS entry: '127.0.0.1 $SITE_NAME.local'"
	CUR_HOSTS=`cat "/etc/hosts"`
	NEW_HOST="127.0.0.1  $SITE_NAME.local"
	echo "$CUR_HOSTS\n$NEW_HOST" > "/etc/hosts"
}
#-------------------------------------------------------------------------
# FUNCTION CREATE_EMPTY_DB_FOR_NEW_SITE
#-------------------------------------------------------------------------
function create_empty_db_for_new_site() 
{
	#-------------------------------------------------------------------------
	# Mysql admin credentials are provided in the file represented by 
	# variable $MYSQL_ADMIN_CONFIG_FILE.
	#-------------------------------------------------------------------------
	# Create the db
	echo_step "Create empty database: $DB_NAME"
	mysqladmin --defaults-extra-file="$MYSQL_ADMIN_CONFIG_FILE" create $DB_NAME

	# Create the user
	echo_step "Create database user:    name=$DB_USER   pwd=$DB_PWD"
	DB_QUERY1="CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PWD'"
	mysql --defaults-extra-file="$MYSQL_ADMIN_CONFIG_FILE"  -e "$DB_QUERY1"

	# Grant privs to the user on this db
	echo_step "Grant database privs: $DB_QUERY2"
	DB_QUERY2="SELECT '$DB_NAME'; GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES ON \`$DB_NAME\`.* TO \`$DB_USER\`@\`localhost\` IDENTIFIED BY '$DB_PWD';"
	mysql --defaults-extra-file="$MYSQL_ADMIN_CONFIG_FILE"  -e "$DB_QUERY2"
}
#-------------------------------------------------------------------------
# FUNCTION INSTALL_DRUPAL_SITE
#-------------------------------------------------------------------------
function install_drupal_site() 
{
	drush site-install $SITE_PROFILE --db-url="mysql://$DB_USER:$DB_PWD@localhost/$DB_NAME" --site-name=$SITE_NAME -y 
}
#-------------------------------------------------------------------------
# FUNCTION CREATE_NEW_SITE
#-------------------------------------------------------------------------
function create_new_site() 
{
	# Create the site directory
	create_site_directory

	# Clone down the code-base from github for this site
	clone_repo 

	# Set up the vhost for this new site (and restart apache)
	config_vhost 

	# Add local DNS entry for your site
	add_local_site_dns_entry

	# Create the db for the new site
	create_empty_db_for_new_site

	# Install the new drupal site
	install_drupal_site

	#-------------------------------------------------------------------------
	# Custom config for performing dev on SLAC site
	#-------------------------------------------------------------------------
#	if [$REPO_URL contains "slac-*.git"] then
		
		#disable webauth so we can login locally
		drush pm-disable webauth

		# disable "dangerous" modules
		drush pm-disable mailchimp 


		# add a local config that ensures no production values for important modules are used (e.g., MailChimp API key)
		#add_local_settings_file
#	fi
#	$APACHE_STOP_STR

	# DEBUG - delete the dir each time around so I don't have to do it manually (script won't run if dir already exists)
#	rmdir $SITE_PATH
}


#-------------------------------------------------------------------------
# MAIN
# 
# Check for existence of this site name in the ~/Sites directory first
#-------------------------------------------------------------------------
function main() {

	if [ "$SITE_NAME" == "" ] || [ "$PORT_NUM" == "" ] || [ "$REPO_URL" == "" ]; then
	        echo "------------------------------------------------------------"
	        echo " $0\n#"
			echo " This script sets up a new local drupal site on Mac OS X."
			echo " Set the script's environment globals to match your local"
			echo " environment (e.g., MAMP, Mac OS native apache/php/mysql, etc.)"
			echo ""
			echo " NOTE: This script needs to be run as 'sudo', as it requires"
			echo " elevated privileges to run all tasks successfully."
			echo ""
	        echo " Parameters:"
	        echo '       1. desired site name* (e.g., my-test-site.local)'
	        echo '       2. port number*  (port number for the site, e.g., http://mysite.local:8888)'
	        echo '       2. github URL*  (for the repo for the drupal code-base)'
	        echo '       3. special site identifier  (e.g., IGP, WWW6 - unique treatments for these)'
	        echo ' Correct Usage: sudo $0 <site-name> <port-num> <github-url> [<special-site-id>]'
	        echo ' e.g.,  $0  my-test-site.local 8888 git@github.com:SLACNationalAcceleratorLaboratory/slac-gtw.git IGP'
	        echo "------------------------------------------------------------"
	else
        create_new_site
#		if [[ ! -e $SITE_PATH ]]; then
#
#	        create_new_site
#	    else
#	        echo "------------------------------------------------------------"
#	        echo "ERROR:"
#	        echo "This site already exists: $SITE_PATH"
#	        echo "Please choose a different site name."
#	        echo "------------------------------------------------------------"
#	    fi
	fi	
}

main

