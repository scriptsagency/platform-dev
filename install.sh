#!/bin/bash

#----------------#
#    INCLUDES    #
#----------------#

script_dir=$(readlink -f "$(dirname "$O")")

if [ ! -f "${script_dir}/config.sh" ]; then
	echo "No config file found at ${script_dir}/config.sh"
	exit 255
else
	source "${script_dir}/config.sh"
fi
if [ ! -f "${script_dir}/functions.sh" ]; then
	echo  "No functions file found at ${script_dir}/functions.sh"
	exit 255
else
	source "${script_dir}/functions.sh"
fi

#---------------------#
#     ARGUMENTS GET   #
#---------------------#

usage="Installation of multisite instance\n
Syntax : $(basename "$0") [ARGS] SITE-NAME\n
\t-?,-h, --help\t\tPrint this message\n
\t-i, \tDefine the installation profile to use\n
\t-s, \tDefine the subfolder name for a new site instance\n
\t-k, --devel\tInclude devel build make\n
\t-v, --verbose\t\tSet the script in verbose mode\n
\t-f, \t\tForce the installation without any request to user input\n
\t\t\t\t(Take care, it might delete automatically your database)\n
\t-d, \t\t\tDefine drush options\n
\t-b, \t\tDefine svn basepath options\n
\t-t, \t\tDefine svn tag version options\n
"

# Configuration of the script
while getopts "i:b:t:d:s:vrfhk?-:" option; do
        #Management of the --options
        if [ "$option" = "-" ]; then
                case $OPTARG in
                        help) option=h ;;
						drush_options)=d ;;
                        verbose) option=v ;;
						force) force=f ;;
						install_profile) option=i ;;
						devel) option=k ;;
						svn_basepath) option=b ;;
						svn_tag_version) option=t ;;
						subdirectory) option=s ;;
                        *)
                                echo "[ERROR] Unknown option --$OPTARG"
                                exit 1
                                ;;
                esac
        fi
        case $option in
				d) drush_options=$OPTARG ;;
                v) verbose=1 ;;
				f) force=1 ;;
				k) devel=1 ;;
				i) install_profile=$OPTARG ;;
				b) svn_basepath=$OPTARG ;;
				t) svn_tag_version=$OPTARG ;;
				s) subdirectory=$OPTARG ;;
                \?|h)
                        echo -e $usage
                        exit 0
                        ;;
                :)
                        echo "[ERROR] Missing arguments for -$OPTARG"
                        exit 1
                        ;;
                ?)
                        echo "[ERROR] Unknown option -$option"
                        exit 1
                        ;;
        esac
done


#------------------------#
#     ARGUMENTS CHECK    #
#------------------------#

# Site name
site_name=$BASH_ARGV
if [ -z "${site_name}" ]; then
	_exit_with_message 230 "No site name was given !!"
fi

# Profile name 
if [ "${install_profile}" != 'multisite_drupal_communities' ] && [ "${install_profile}" != 'multisite_drupal_standard' ]; then 
	_exit_with_message 220 "Profile name '${install_profile}' is incorrect" 
fi

# Get current configuration
current_dir=$(pwd)
__echo "Set current directory to ${current_dir}"
working_dir="${current_dir}/${site_name}"
__echo "Set working directory to ${working_dir}"

# Set up the drush option
if [ "${force}" = 1 ] ; then
	drush_options="${drush_options} -y"
fi
__echo "Set drush options: ${drush_options}"

# set DB connection
db_name="$site_name"
__echo "Set DB URL to mysqli://${db_user}:DB_PASS@${db_host}:${db_port}/${db_name}"
db_url="mysqli://${db_user}:${db_pass}@${db_host}:${db_port}/${db_name}"

# create database if not exist
_create_database

# Set up target directory 
if [ -n "${subdirectory}" ]; then 
	if [ ! -e "${webroot}/${subdirectory}" ] ; then
		mkdir "${webroot}/${subdirectory}" || _exit_with_message 190 "Unable to create subdirectory '${webroot}/${subdirectory}'"
	fi
	base_path="${base_path}/${subdirectory}"
	webroot="${webroot}/${subdirectory}"
fi

# cleanup target directory
if [ -d "${webroot}/${site_name}" ] ; then
	__echo "The folder '${webroot}/${site_name}' already exist, it will be deleted" 'warning'
	_continue
	chmod 744 -Rf "${webroot}/${site_name}"
	rm -Rf "${webroot}/${site_name}"  
	__echo "Removing the folder $webroot/${site_name} done" 'status'
fi

# cleanup existing working directory
if [ -d "${working_dir}" ] ; then
	__echo "Removing existing working directory..."
	__fix_perms -R "${working_dir}"
	rm -Rf "${working_dir}"
	__echo "done" 'status'
fi

# cleanup tmp directory
if [ -d "${working_dir}_sources_tmp" ] ; then
  rm -Rf "${working_dir}_sources_tmp"  
fi

#svn conf
if [ "$svn_basepath" = "trunk" ] || [ "$svn_basepath" = "tags" ] || [ "$svn_basepath" = "branches" ]; then
	svn=1
fi

#----------------------#
#     BUILD SOURCES    #
#----------------------#

# get own source from svn ?
if [ "${svn}" = 1 ] ; then 
	# files to retrieve from SVN (we don't recover all files, eg custom subsite is useless)
	svn_files=(
		"profiles"
		"sites/all"
		"sites/default"
		"patches"
	)
	# build svn_path
	if [ "$svn_basepath" = "trunk" ] ; then
		svn_path="${svn_url}/${svn_basepath}"
	else
		svn_path="${svn_url}/${svn_basepath}/${svn_tag_version}/source"
	fi
	__echo "SVN repository path set to ${svn_path}"
	own_source_path="${working_dir}_sources_tmp"
	__echo "own_source_path path set to ${own_source_path}"
	_get_svn_sources 
else
	own_source_path="${current_dir}"
fi

# Get Drupal core and contributed sources using makefile
_get_make_sources "${own_source_path}/profiles/${install_profile}/build.make"

#  makefile for devel modules
if [ "${devel}" = 1 ] ; then
	_get_make_sources "${own_source_path}/profiles/devel.make"
fi

# copy own source (svn or local) to working dir
cp -R "${own_source_path}/profiles/multisite_drupal_core" "${working_dir}/profiles"
cp -R "${own_source_path}/profiles/${install_profile}" "${working_dir}/profiles"
cp -R "${own_source_path}/sites/all/modules/" "${working_dir}/sites/all"
cp -R "${own_source_path}/sites/all/themes" "${working_dir}/sites/all"
cp -R "${own_source_path}/sites/all/libraries" "${working_dir}/sites/all"
cp -R "${own_source_path}/sites/default/files/" "${working_dir}/sites/default/files/"
cp "${own_source_path}/sites/default/proxy.settings.php" "${working_dir}/sites/default/"	

cd "${site_name}"

#-----------------------#
#     APPLY PATCHES     #
#-----------------------#

# we assume the script is in the patches directory
#patch_dir=$(readlink -f patches)
patch_dir="${own_source_path}/patches"

patch_dir_core="${patch_dir}/multisite_drupal_core"
#__echo "$patch_dir_core" 'error'
# BACKPORT version <=1.6 : if $patch_dir_core not found we apply patches directly from $patch_dir folder
if [ ! -e "$patch_dir_core" ]; then 
	__echo "Applying core patches from $patch_dir to ${site_name}"
	_apply_patches "$patch_dir"
else
	# core patchs patch
	__echo "Applying core patches from ${patch_dir_core} to ${site_name}"
	_apply_patches "$patch_dir_core"
	
	# profile patchs
	patch_dir_profile="${patch_dir}/${install_profile}"
	if [ ! -e "$patch_dir_profile" ]; then 
		__echo "Applying core patches from ${patch_dir_core} to ${site_name}"
		_apply_patches "$patch_dir_profile"
	fi
fi

#-----------------#
#     INSTALL     #
#-----------------#
# install and configure the drupal instance
drush ${drush_options} --php="/usr/bin/php" si "$install_profile" --db-url="$db_url" --account-name="$account_name" --account-pass="$account_pass" --site-name="${site_name}" --site-mail="$site_mail"  1>&2

#----------------#
#     CONFIG     #
#----------------#

# set solR config
_setsolrconf

#inject data

_inject_data "${own_source_path}/profiles/${install_profile}/inject_data.php"

#set alias for CodeSniffer
alias codercs='phpcs --standard=sites/all/modules/contributed/coder/coder_sniffer/Drupal/ruleset.xml --extensions=php,module,inc,install,test,profile,theme'

#flush cache and rebuild access
_node_access_rebuild 

#solr indexation
__echo "Run solr indexation.."
drush ${drush_options} solr-index

#run cron
__echo "Run drupal cron..."
drush cron

#remove links from the linkchecker
_setlinkcheckerconf

mkdir "${working_dir}/sites/default/files/private_files"

# cleanup && move to target directory
if [ "${svn}" = 1 ] ; then 
	rm -Rf "${own_source_path}"
fi
mv "${working_dir}" "${webroot}"
__fix_perms "${webroot}"

__echo "\nSite installed on ${webroot}/${site_name}" 'status'




