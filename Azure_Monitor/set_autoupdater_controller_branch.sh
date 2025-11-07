#!/bin/bash
# bin variables
LS=/bin/ls
ECHO=/bin/echo
# general variables
SUCCESS=0
FAILURE=1
# command variables
AUTOUPDATER_DIR=/opt/AutoUpdater
AUTOUPDATER=${AUTOUPDATER_DIR}/latest/bin/autoupdatercli
VERSION="$(cpprod_util CPPROD_GetVerText CPShared | tr "." "_" | xargs)"
# exit codes
FAILED_TO_RESOLVE_BRANCH_FROM_VERSION_NAME=2
revert_from_specific_branch=1

function is_valid_cloudguard_controller_version() {
    local to_find=${1}
    cloudguard_controller_branches=("prod" "dev" "qa")
    for item in "${cloudguard_controller_branches[@]}"; do
        if [ "${item}" == "${to_find}" ]; then
            return $SUCCESS
        fi
    done
    return $FAILURE
}

function get_cloudguard_controller_target_branch_name() {
    branch_info=$1
    # convert Cloudguard Controller target version to lower-case and remove trailing and leading spaces
    CLOUDGUARD_CONTROLLER_TARGET_BRANCH_SUFFIX=$($ECHO "$branch_info" | awk '{print tolower($0)}' | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print }')
    # if the parameter is a valid branch name suffix
    is_valid_cloudguard_controller_version $CLOUDGUARD_CONTROLLER_TARGET_BRANCH_SUFFIX
    cloudguard_controller_branch_exists=$?
    if [ $cloudguard_controller_branch_exists -eq $SUCCESS ]; then
        if [ "$CLOUDGUARD_CONTROLLER_TARGET_BRANCH_SUFFIX" = "prod" ]; then
            CLOUDGUARD_CONTROLLER_TARGET_BRANCH_SUFFIX=""
            $ECHO "CloudGuard_Controller_"$VERSION"_AutoUpdate"
        else
            $ECHO "CloudGuard_Controller_"$VERSION"_AU_$CLOUDGUARD_CONTROLLER_TARGET_BRANCH_SUFFIX"
        fi
    else
        # Use specific branch name.
        $ECHO $1
    fi
}

function update_products_conf_branches_name() {
    local products_config_path=$1
    if [ -f "$products_config_path" ]; then
        if [ $revert_from_specific_branch == 0 ]; then
            sed -r -i -e "s/branch=\"${2}\"/branch=\"${CLOUDGUARD_CONTROLLER_TARGET_BRANCH}\"/g" "$products_config_path"
        else
            sed -r -i -e "s/branch=\"CloudGuard_Controller_${VERSION}_A((U_(dev|qa))|utoUpdate)?\"/branch=\"${CLOUDGUARD_CONTROLLER_TARGET_BRANCH}\"/g" "$products_config_path"
        fi

        if [ $? -ne $SUCCESS ]; then
            $ECHO "Error: Failed to set branch in $products_config_path"
        fi
    fi
}

function display_help() {
    $ECHO "Usage: $0 [OPTIONS] <branch> [current_branch]"
    $ECHO "Options:"
    $ECHO "  -h, --help    Display this help message"
    $ECHO "Arguments:"
    $ECHO "  <branch>  The branch name to switch to. Valid values are 'prod', 'qa', 'dev', or a specific branch name."
    $ECHO "  [current_branch]  (Optional) The current branch name to switch from."
    $ECHO ""
    $ECHO "Scenarios:"
    $ECHO "  1. Switch to the 'prod' branch:"
    $ECHO "     $0 prod"
    $ECHO "  2. Switch to the 'qa' branch:"
    $ECHO "     $0 qa"
    $ECHO "  3. Switch to the 'dev' branch:"
    $ECHO "     $0 dev"
    $ECHO "  4. Switch to a specific branch:"
    $ECHO "     $0 <branch_name>"
    $ECHO "  5. Switch from a specific branch to another branch:"
    $ECHO "     $0 <new_branch> <current_branch>"
}

$ECHO "Updating Cloudguard Controller branch in AutoUpdater..."
# verify exactly 1 or 2 parameters are given
if [ $# == 2 ]; then
    revert_from_specific_branch=0
elif [ $# -ne 1 ]; then
    $ECHO "Error: please provide exactly 1 or 2 parameters - PROD/DEV/QA or a specific branch name, and optionally the current branch name"
    exit $FAILURE
fi

# Check for help option
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    display_help
    exit $SUCCESS
fi

CLOUDGUARD_CONTROLLER_TARGET_BRANCH=""
# if user input is version name
if [ ! -z $1 ]; then
    CLOUDGUARD_CONTROLLER_TARGET_BRANCH=$(get_cloudguard_controller_target_branch_name $1)
    if [ -z $CLOUDGUARD_CONTROLLER_TARGET_BRANCH ]; then
        $ECHO "Error: Failed to resolve target branch from version input - please make sure you typed the branch name correctly (PROD/DEV/QA) or provided specific branch name"
        exit $FAILED_TO_RESOLVE_BRANCH_FROM_VERSION_NAME
    fi
fi

# if AutoUpdater dir exists
if [ -d $AUTOUPDATER_DIR ]; then
    autoupdater_dir_contents=($($LS $AUTOUPDATER_DIR --ignore='latest'))
    if [ -f ${AUTOUPDATER_DIR}/productsConfig/products_config.xml ]; then
        update_products_conf_branches_name "${AUTOUPDATER_DIR}/productsConfig/products_config.xml" $2
    fi
    for item in "${autoupdater_dir_contents[@]}"; do
        # modify config file of each version that exists inside AutoUpdater dir
        if [ -f ${AUTOUPDATER_DIR}/${item}/conf/products_config.xml ]; then
            update_products_conf_branches_name "${AUTOUPDATER_DIR}/${item}/conf/products_config.xml" $2
        fi
    done
else
    $ECHO "Error: AutoUpdater directory is missing"
	exit $FAILURE
fi

$ECHO "Stopping AutoUpdater, please wait..."
$AUTOUPDATER stop
if [ $? -eq $SUCCESS ]; then
    $ECHO "Successfully stopped AutoUpdater"
    $ECHO "*******************************************************************************************************************************"
    $ECHO "Cloudguard Controller branch in AutoUpdater set successfully to: \"$CLOUDGUARD_CONTROLLER_TARGET_BRANCH\" - the change will take effect when AutoUpdater is run again"
    $ECHO "*******************************************************************************************************************************"
else
    $ECHO "*****************************************************************************************************"
    $ECHO "Error: failed to stop AutoUpdater - please attempt to stop AutoUpdater manually or run the script again"
    $ECHO "*****************************************************************************************************"
fi