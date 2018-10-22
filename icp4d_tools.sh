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
  echo "      -i, --interactive: Run the tool in an interactive mode"
  echo "      -p, --preinstall: Run pre-installation requirements checker (CPU, RAM, and Disk space, etc.)"
  echo "      -h, --health: Run post-installation cluster health checker"
  echo "      -c, --collect=smart|standard: Run log collection tool to collect diagnostics and logs files from every pod/container. Default is smart"
  echo "      -lt, --logtail=-1|K Capture last K lines or all when -1, works with stanard collect mode" 
  echo "      -h, --help: Prints this message"
  echo -e "\n  EXAMPLES:"
  echo "      $0 -preinstall"
  echo "      $0 --health"
  echo "      $0 --collect=smart"
  echo
  exit 0
}

Selected_Option() {
  #entry to the tool
	
  #Switch between Wizard or Param driven tooling 
		
  if [ ! -z ${_ICP_INTERACTIVE} ]; then
     echo " switching to Wizard Based"
     ICP_Tools_Menu
     exit
  fi
	
  if [ ! -z ${_ICP_HELP} ]; then
     Print_Usage;
     exit
  fi
	
  if [ ! -z ${_ICP_COLLECT} ]; then
     Collect_Logs;
  fi
	
	
  if [ ! -z ${_ICP_HEALTH} ]; then
     Health_CHK;
     #Resource_CHK;
  fi
	
  if [ ! -z ${_ICP_PREINSTALL} ]; then
     Prereq_CHK;
  fi
}


setup() {
    export HOME_DIR=`pwd`
    export UTIL_DIR=`pwd`"/util"
    export LOG_COLLECT_DIR=`pwd`"/log_collector"
    export PLUGINS=`pwd`"/log_collector/plugins"
    . $UTIL_DIR/util.sh
    . $UTIL_DIR/get_params.sh
    . $LOG_COLLECT_DIR/icpd-logcollector-master-nodes.sh
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
        local logs_dir=`mktemp -d`
        cd $HOME_DIR
        ./health_check/icpd-health-check-master.sh
        local timestamp=`date +"%Y-%m-%d-%H-%M-%S"`
        local archive_name="logs_"$$"_"$timestamp".tar.gz"
        local output_dir=`mktemp -d -t icp4d_collect_log.XXXXXXXXXX`
        build_archive $output_dir $archive_name $logs_dir "./"
        echo Logs collected at $output_dir/$archive_name
        clean_up $logs_dir
}

Collect_Down_Pod_Logs() {
	local logs_dir=`mktemp -d`
        cd $HOME_DIR
	#run_on_all_nodes ./log_collector/icplogcollector-all-nodes.sh $logs_dir
	#run_on_all_nodes ./log_collector/icplogcollector-master-nodes.sh $logs_dir
        ./log_collector/icpd-logcollector-master-nodes.sh $logs_dir
	local timestamp=`date +"%Y-%m-%d-%H-%M-%S"`
	local archive_name="logs_"$$"_"$timestamp".tar.gz"
	local output_dir=`mktemp -d -t icp4d_collect_log.XXXXXXXXXX`
	build_archive $output_dir $archive_name $logs_dir "./"
	echo Logs collected at $output_dir/$archive_name
	clean_up $logs_dir
}

Collect_Component_Logs() {
        export COMPONENT=dsx
        export logs_dir=`mktemp -d`
        export LINE=500

        cd $HOME_DIR
        for cmd in `cat ./log_collector/component_sets/dsx_logs.set`
        do
           . $PLUGINS/$cmd
        done
        local timestamp=`date +"%Y-%m-%d-%H-%M-%S"`
        local archive_name="logs_"$$"_"$timestamp".tar.gz"
        local output_dir=`mktemp -d -t icp4d_collect_log.XXXXXXXXXX`
        build_archive $output_dir $archive_name $logs_dir "./"
        echo Logs collected at $output_dir/$archive_name
        clean_up $logs_dir
}


Collect_DB2_Hang_Logs() {
        export COMPONENT=db2
        export logs_dir=`mktemp -d`
        export LINE=500
        export DB2POD=`kubectl get pod --all-namespaces --no-headers -o custom-columns=NAME:.metadata.name|grep db2`

        cd $HOME_DIR
        for cmd in `cat ./log_collector/component_sets/db2_hang_log.set`
        do
           . $PLUGINS/$cmd
        done
        local timestamp=`date +"%Y-%m-%d-%H-%M-%S"`
        local archive_name="logs_"$$"_"$timestamp".tar.gz"
        local output_dir=`mktemp -d -t icp4d_collect_log.XXXXXXXXXX`
        build_archive $output_dir $archive_name $logs_dir "./"
        echo Logs collected at $output_dir/$archive_name
        clean_up $logs_dir
}


Resource_CHK(){
        echo -e "****************** \n";
        echo -e "Resources Usage at cluster level....\n"
        kubectl top node
        echo -e "Detailed Resource Usage for every node.......";
        echo
        nodes=$(kubectl get node --no-headers -o custom-columns=NAME:.metadata.name)
        for node in $nodes; do
           echo "Rescoure usage for Node: $node"
           kubectl describe node "$node" | sed '1,/Non-terminated Pods/d'
           echo
           echo "Disk usages for Node: $node"
           ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=no \
                -o ConnectTimeout=10 -Tn $node 'du -h'
           echo
        done
}

ICP_Tools_Menu() {
  while true; do
    echo -e "Choose an option [1-7] \n";
    options=("Pre-install checks for ICPD installation" "Health-check an installed ICPD cluster" "Collect diagnostics data for down pods" "Collect diagnostics data for DSX" "Collect diagnostics data for DB2" "List Resource Usage" "Exit")
    COLUMNS=12;
    select opt in "${options[@]}";
    do
    	case $opt in
        "Pre-install checks for ICPD installation")
          Prereq_CHK; break;;
    	"Health-check an installed ICPD cluster")
    	  Health_CHK; break;;
        "Collect diagnostics data for down pods")
          Collect_Down_Pod_Logs; break;;
        "Collect diagnostics data for DSX")
          Collect_Component_Logs; break;;
        "Collect diagnostics data for DB2")
          Collect_DB2_Hang_Logs; break;;
	"List Resource Usage")
	  Resource_CHK; break;;
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
#Selected_Option $@
ICP_Tools_Menu
