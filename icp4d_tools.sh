#!/bin/bash

# formatting
LINE=$(printf "%*s\n" "30" | tr ' ' "#")


echo -e "\n${LINE}"
echo "ICP for Data Tools Version: $ICP_Tools_Version"
echo "Release Date: $Release_Date"
echo -e "\nTested on:"
Product_Version=""
for Product_Version in "${Product_Versions[@]}"; do
  echo "$Product_Version"
done
echo ${LINE}
echo

setup() {
	export UTIL_DIR=`pwd`"/util"
    . $UTIL_DIR/util.sh
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

setup $@
Collect_Logs $@
