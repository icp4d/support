#!/bin/bash

# formatting
LINE=$(printf "%*s\n" "30" | tr ' ' "#")


#echo -e "\n${LINE}"
#echo "ICP for Data Tools Version: $ICP_Tools_Version"
#echo "Release Date: $Release_Date"
#echo -e "\nTested on:"
#Product_Version=""
#for Product_Version in "${Product_Versions[@]}"; do
  #echo "$Product_Version"
#done
#echo ${LINE}
#echo

Print_Usage() {
  echo "Usage:"
  echo "$0 [OPTIONS]"
  echo -e "\n  OPTIONS:"
  echo "      -pre: Run pre-installation requirements checker (CPU, RAM, and Disk space, etc.)"
  echo "      -health: Run post-installation cluster health checker"
  echo "      -l, --log: Run log collection tool to collect log files from critical pods/containers"
  echo "      -h, --help: Prints this message"
  echo -e "\n  EXAMPLES:"
  echo "      $0 -pre"
  echo "      $0 -health"
  echo "      $0 --log"
  echo
  exit 0
}

Selected_Option() {
    TEMP=`getopt -o plh: --long pre,health,log,help: -n 'icptools.sh' -- "$@"`

    if [ $? != 0 ] ; then 
        echo "error processing options..." >&2 
        exit 1
    fi

    eval set -- "$TEMP"

    TASK=""
    while true; do
        case "$1" in
            -h | --help ) TASK=Print_Usage; shift ;;
            -p | --pre  ) TASK=Prereq_CHK; shift ;;
            -l | --log ) TASK=Collect_Logs; shift ;;
            --health ) TASK=Health_CHK; shift ;;
            -- ) shift; break ;;
            * ) break ;;
        esac
    done
    if [ ! -z "$TASK" ]; then
        $TASK $@
        exit $?
    fi
}


setup() {
	export UTIL_DIR=`pwd`"/util"
    . $UTIL_DIR/util.sh
}
Prereq_CHK() {
        local result=preInstallCheckResult
	local logs_dir=`mktemp -d`
	/ibm/InstallPackage/pre_install_check.sh --type="master"
	local timestamp=`date +"%Y-%m-%d-%H-%M-%S"`
	local archive_name="logs_"$$"_"$timestamp".tar.gz"
	local output_dir=`mktemp -d -t icp4d_collect_log.XXXXXXXXXX`
        test -e /tmp/$result && cp /tmp/$result $logs_dir/$result.`hostname`
	build_archive $output_dir $archive_name $logs_dir "./"
	echo Logs collected at $output_dir/$archive_name
	clean_up $logs_dir
}

Health_CHK() {
        exit
}

Collect_Logs() {
	local logs_dir=`mktemp -d`
	#run_on_all_nodes ./log_collector/icplogcollector-all-nodes.sh $logs_dir
	#run_on_all_nodes ./log_collector/icplogcollector-master-nodes.sh $logs_dir
	./log_collector/icplogcollector-master-nodes.sh $logs_dir
	local timestamp=`date +"%Y-%m-%d-%H-%M-%S"`
	local archive_name="logs_"$$"_"$timestamp".tar.gz"
	local output_dir=`mktemp -d -t icp4d_collect_log.XXXXXXXXXX`
	build_archive $output_dir $archive_name $logs_dir "./"
	echo Logs collected at $output_dir/$archive_name
	clean_up $logs_dir
}

ICP_Tools_Menu() {
  while true; do
    echo -e "Choose an option [1-4] \n";
    options=("Pre-install checks for ICPD installation" "Health-check an installed ICPD cluster" "Collect diagnostics data" "Exit")
    COLUMNS=12;
    select opt in "${options[@]}";
    do
    	case $opt in
        "Pre-install checks for ICPD installation")
          Prereq_CHK; break;;
    	"Health-check an installed ICPD cluster")
    	  Health_CHK; break;;
        "Collect diagnostics data")
          Collect_Logs; break;;
        "Exit")
      		exitSCRIPT; break;;
    		*)
    			echo invalid option;
    			;;
    	esac
    done
  done
}

exitSCRIPT(){
  echo -e "Exiting...";
  exit 0;
}

setup $@
Selected_Option $@
ICP_Tools_Menu
