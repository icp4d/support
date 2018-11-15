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
  echo "       --preinstall: Run pre-installation requirements checker (CPU, RAM, and Disk space, etc.)"
  echo "       --health: Run post-installation cluster health checker"
  echo "       --collect=smart|standard: Run log collection tool to collect diagnostics and logs files from every pod/container. Default is smart"
  echo "          --component=db2,dsx: Run DB2 Hand log collection,DSX Diagnostics logs collection. Works with --collect=standard option"
  echo "          --persona=c,a,o: Runs a focused log collection from specific pods related to a personas Collect, Organize and Analyze. Works with --collect=standard option"
  echo "          --line=N: Capture N number of rows from pod log"
  echo "       --help: Prints this message"
  echo -e "\n  EXAMPLES:"
  echo "      $0 --preinstall"
  echo "      $0 --health"
  echo "      $0 --collect=smart"
  echo "      $0 --collect=standard --component=db2,dsx"
  echo "      $0 --collect=standard --persona=c,a"
  echo
  exit 0
}

Selected_Option() {
  #entry to the tool
      
  if [ $# -eq 0 ] || [ ! -z ${_ICP_HELP} ] ; then
    Print_Usage
    exit 0
  fi

  if [ ! -z ${_ICP_HELP} ]; then
    echo ewwww
    Print_Usage;
    exit
  fi

  if [ ! -z $_ICP_LINE ]; then
    export LINE=$_ICP_LINE
  fi
	
  #Switch between Wizard or Param driven tooling 
  
  sanity_checks
		
  if [ ! -z ${_ICP_INTERACTIVE} ]; then
    echo " switching to Wizard Based"
    ICP_Tools_Menu
    exit
  fi

	
  if [ ! -z ${_ICP_COLLECT} ]; then
    Collect_Logs $@;
  fi

  if [ ! -z ${_ICP_HEALTH} ]; then
    Health_CHK;
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

  export LINE=500

  source $UTIL_DIR/util.sh
  . $UTIL_DIR/get_params.sh
  #. $LOG_COLLECT_DIR/icpd-logcollector-master-nodes.sh

}




setupCollectionDirectory()
{
  if [ -z "$LOGS_DIR" ]; then 
    LOGS_DIR=`mktemp -d`
	    
  fi
}


Prereq_CHK() {
  /ibm/InstallPackage/pre_install_check.sh --type="master"  | tee preinstall_check.log 
}


Health_CHK() {
  local logs_dir=`mktemp -d`
  cd $HOME_DIR
  ./health_check/icpd-health-check-master.sh | tee health_check.log
}



Collect_Logs() {
  local logs_dir=`mktemp -d`
  cd $HOME_DIR

  if [[ "$_ICP_COLLECT" == standard ]]; then

    pluginset="./log_collector/component_sets/collect_all_pod_logs.set"
    # Check for component
    if [ ! -z $_ICP_COMPONENT ] && [ $_ICP_COMPONENT = db2 ]; then
       export COMPONENT=db2
       export DB2POD=`kubectl get pod --all-namespaces --no-headers -o custom-columns=NAME:.metadata.name|grep $COMPONENT`
       pluginset="./log_collector/component_sets/db2_hang_log.set 
                  ./log_collector/component_sets/collect_all_pod_logs.set"
    elif [ ! -z $_ICP_COMPONENT ] && [ $_ICP_COMPONENT = dsx ]; then
       export COMPONENT=dsx
       pluginset="./log_collector/component_sets/dsx_logs.set 
                  ./log_collector/component_sets/collect_all_pod_logs.set"
    elif [ ! -z $_ICP_PERSONA ]; then
       export PERSONA=`echo $_ICP_PERSONA| awk '{print toupper($0)}'`
       pluginset="./log_collector/component_sets/collect_all_pod_logs.set"
    fi

  elif [[ "$_ICP_COLLECT" == smart ]]; then

    pluginset="./log_collector/component_sets/collect_down_pod_logs.set"

  else

    #future we might have more modes, for now defaulting to smart.
    pluginset="./log_collector/component_sets/collect_down_pod_logs.set"

  fi

  for cmd in `cat ${pluginset}`
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



Collect_Component_Logs() {
  export COMPONENT=dsx
  export logs_dir=`mktemp -d`
  #export LINE=500

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
  export DB2POD=`kubectl get pod --all-namespaces --no-headers -o custom-columns=NAME:.metadata.name|grep $COMPONENT`

  echo "Collecting diagnostics data for $COMPONENT"
  echo "------------------------------------------"

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
    	  echo "hhelloo" $opt; Prereq_CHK; break;;
    	"Health-check an installed ICPD cluster")
    	  Health_CHK; break;;
        "Collect diagnostics data for down pods")
          Collect_Logs; break;;
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
Selected_Option $@
