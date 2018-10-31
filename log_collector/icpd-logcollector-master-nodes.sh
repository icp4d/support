#!/bin/bash
#run only on master nodes

setup() {
    . $UTIL_DIR/util.sh
    #commonly used func are inside of util.sh
    CONFIG_DIR=$INSTALL_PATH

    #TEMP_DIR=$OUTPUT_DIR	
    PRE_STR=$(get_prefix)

    LOG_FILE="/tmp/icp_checker.log"
    echo
    echo =============================================================
    echo
    echo Running ICP for Data Log Collector Mode [ $1 ] ...
    #echo ICP Version: $PRODUCT_VERSION
    #echo Release Date: $RELEASE_DATE
    echo =============================================================
}

myEcho()
{
  echo -n $1
}


healthy_pods_log_collector(){
    local tempdir=$logs_dir
    #local line=$LINE
    local line=50
    myEcho "Collecting logs for healthy pods..."
    TmpFileForPods=$(mktemp /tmp/icpd-temp.XXXXXXXXXX)
    trap 'rm -f $TmpFileForPods' EXIT
    name_space=`kubectl get namespaces --no-headers|awk '{print $1}'`
    for ns in `echo $name_space`
    do
        all_pods=`kubectl get pods -n $ns --no-headers|awk '{print $1}'`
        for dp in `echo $all_pods`
        do
           echo "echo '### '" >> $TmpFileForPods
           echo "echo '### NAMESPACE=$ns, POD=$dp ###'" >> $TmpFileForPods
           echo "echo '### kubectl logs -n $ns $dp --tail=$line'" >> $TmpFileForPods
           #echo "kubectl logs -n $ns -p $dp -c $cnt" >> $TmpFileForPods
           echo "kubectl logs -n $ns  $dp --tail=50 2>/dev/null" >> $TmpFileForPods
        done
    done
    get_log_by_cmd $tempdir log_for_healthy_pods "sh $TmpFileForPods"
    rm -f $TmpFileForPods
    trap - EXIT
}


down_pods_log_collector(){
    local tempdir=$logs_dir
    myEcho "Collecting logs for down pods..."
    TmpFileForDownPods=$(mktemp /tmp/icpd-temp.XXXXXXXXXX)
    trap 'rm -f $TmpFileForDownPods' EXIT
    name_space=`kubectl get namespaces --no-headers|awk '{print $1}'`
    for ns in `echo $name_space`
    do
        down_pods=`kubectl get pods -n $ns --no-headers|egrep -v 'Running|Complete'|awk '{print $1}'`
        for dp in `echo $down_pods`
        do
           container=`kubectl get pods -n $ns $dp -o jsonpath='{@.spec.containers[*].name}'`
           for cnt in `echo $container`
           do
               echo "echo '### '" >> $TmpFileForDownPods
               echo "echo '### NAMESPACE=$ns, POD=$dp, CONTAINER=$cnt ###'" >> $TmpFileForDownPods
               echo "echo '### kubectl logs -n $ns -p $dp -c $cnt'" >> $TmpFileForDownPods
               echo "kubectl logs -n $ns -p $dp -c $cnt" >> $TmpFileForDownPods
           done
        done
    done
    get_log_by_cmd $tempdir log_for_down_pods "sh $TmpFileForDownPods"
    rm -f $TmpFileForDownPods
    trap - EXIT
}

node_resource_usage(){
    local tempdir=$logs_dir
    myEcho "Collecting detailed resource usage for each node..."
    TmpFileForResource=$(mktemp /tmp/icpd-temp.XXXXXXXXXX)
    trap 'rm -f $TmpFileForResource' EXIT
    nodes=$(kubectl get node --no-headers -o custom-columns=NAME:.metadata.name)
    for node in $nodes; do
       echo "echo ' '" >> $TmpFileForResource
       echo "echo '### '" >> $TmpFileForResource
       echo "echo '### Rescoure usage for Node: $node ###'" >> $TmpFileForResource
       echo "kubectl describe node $node | sed '1,/Non-terminated Pods/d'" >> $TmpFileForResource
       echo "echo ' '" >> $TmpFileForResource
       echo "echo '### Disk usage for Node: $node ###'" >> $TmpFileForResource
       echo "ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=no \
                -o ConnectTimeout=10 -Tn $node 'du -h'" >> $TmpFileForResource
    done
    get_log_by_cmd $tempdir resource_usage_by_node "sh $TmpFileForResource"
    rm -f $TmpFileForResource
    trap - EXIT
}

pod_description_down_pods(){
    local tempdir=$logs_dir
    myEcho "Collecting pod desciption for down pods..."
    tmpfile=$(mktemp /tmp/icpd-temp.XXXXXXXXXX)
    trap 'rm -f $tmpfile' EXIT
    kubectl get pods --all-namespaces --no-headers | egrep -v 'Running|Completed' | awk '{print "kubectl describe pod " $2 " --namespace="$1";"}' > $tmpfile
    get_log_by_cmd $tempdir pod_description "sh $tmpfile"
    rm -f $tmpfile
    trap - EXIT
}

component_log_collector(){
    local component=$COMPONENT
    local tempdir=$logs_dir
    local line=$LINE

    echo
    echo Collecting log for $component...
    echo -----------------------------
    name_space=zen
    pod_list=`kubectl get pods -n $name_space --no-headers|egrep -i $component|awk '{print $1}'`
    for current_pod in `echo $pod_list`
    do
       container=`kubectl get pods -n $name_space $current_pod -o jsonpath='{@.spec.containers[*].name}'`
       for cnt in `echo $container`
       do
          outfile=`echo "$component"PodLogs_"$name_space"_"$current_pod"_"$cnt"`
          cmd="kubectl logs -n $name_space --tail=$line $current_pod -c $cnt"
          get_log_by_cmd $tempdir $outfile "$cmd"
       done
    done
}


check_log_file_exist() {
	local log_file=$1
	local name=$2
	if [ -f $log_file ]; then
                print_passed_message "$name collected: $log_file"
                #print_passed_message ""
        else
                print_failed_message "failed to collect $name"
        fi
}

get_log_by_cmd(){
	local temp_dir=$1
	local name=$2
	local cmd=$3
	local log_file=$temp_dir"/$name"
	eval $cmd > $log_file
	check_log_file_exist $log_file $name
}



get_container_log_by_name() {
    local temp_dir=$1
    local container_name=$2
    local log_file=$temp_dir"/"$container_name".log"
    local container_id=$(docker ps |grep $container_name|awk '{print $1}')
    docker logs $container_id >$log_file 2>&1
    
    if [ -f $log_file ]; then
        print_passed_message "$container_name log generated $log_file"
    else
        print_failed_message "failed to generate $container_name log:"
    fi
}


typeset -fx setup
typeset -fx sanity_checks
#typeset -fx log_collector $TEMP_DIR
typeset -fx log_collector
typeset -fx component_log_collector
typeset -fx check_log_file_exist
typeset -fx get_log_by_cmd
typeset -fx get_container_log_by_name

TEMP_DIR=$1    ###sanjitc ####
