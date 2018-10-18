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
    echo Running ICP for Data Checker in Log Collector mode ...
    #echo ICP Version: $PRODUCT_VERSION
    #echo Release Date: $RELEASE_DATE
    echo =============================================================
}

log_collector() {
    local temp_dir=$1
	echo
        echo Collecting os information...
        echo ------------------------
	get_log_by_cmd $temp_dir os_info "uname -a"

	echo
        echo Collecting Redhat release information...
        echo ------------------------
	get_log_by_cmd $temp_dir readhat_release "cat /etc/redhat-release"

	echo
	echo Collecting mem info...
        echo ------------------------
	get_log_by_cmd $temp_dir mem_info "cat /proc/meminfo"

        echo
        echo Collecting docker version...
        echo ------------------------
        get_log_by_cmd $temp_dir docker_version "docker version"

        echo
        echo Collecting docker info...
        echo ------------------------
        get_log_by_cmd $temp_dir docker_info "docker info"

        echo
        echo Collecting docker images info...
        echo ------------------------
        get_log_by_cmd $temp_dir docker_images "docker images"

        echo
        echo Collecting docker ps info...
        echo ------------------------
        get_log_by_cmd $temp_dir docker_ps_a "docker ps -a"

        echo
        echo Collecting docker status...
        echo ------------------------
        get_log_by_cmd $temp_dir docker_status "systemctl status docker"

        echo
        echo Collecting docker log...
        echo ------------------------
        get_log_by_cmd $temp_dir docker_log "journalctl -u docker"

        echo
        echo Collecting kubelet config...
        echo ------------------------
        get_log_by_cmd $temp_dir kubelet_config "cat /var/lib/kubelet/kubelet-config"

        echo
        echo Collecting kubelet status...
        echo ------------------------
        get_log_by_cmd $temp_dir kubelet_status "systemctl status kubelet"

        echo
        echo Collecting kubelet log...
        echo ------------------------
        get_log_by_cmd $temp_dir kubelet_log "journalctl -u kubelet"

        echo
        echo Collecting kubelet node status...
        echo ------------------------
        get_log_by_cmd $temp_dir kubelet_get_nodes "kubectl get nodes"

        echo
        echo Collecting kubelet pod status...
        echo ------------------------
        get_log_by_cmd $temp_dir kubelet_get_pods "kubectl get pods --all-namespaces -o wide"

        echo
        echo Collecting kubelet pvc status...
        echo ------------------------
        get_log_by_cmd $temp_dir kubelet_get_pvc "kubectl get pvc --all-namespaces"

        echo
        echo Collecting gluster info...
        echo ------------------------
        get_log_by_cmd $temp_dir gluster_volume_info "gluster volume info"

        echo
        echo Collecting gluster volume status...
        echo ------------------------
        get_log_by_cmd $temp_dir gluster_volume_status "gluster volume status"

        echo
        echo Collecting resource usage at cluster level...
        echo ------------------------
        get_log_by_cmd $temp_dir kubectl_top_node "kubectl top node"

        echo
        echo Collecting detailed resource usage for each node...
        echo ------------------------
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
           echo "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=no \
                -o ConnectTimeout=10 -Tn $node 'du -h'" >> $TmpFileForResource
        done
        get_log_by_cmd $temp_dir resource_usage_by_node "sh $TmpFileForResource"
        rm -f $TmpFileForResource
        trap - EXIT

        echo
        echo Collecting pod desciption for down pods...
        echo ------------------------
        tmpfile=$(mktemp /tmp/icpd-temp.XXXXXXXXXX)
        trap 'rm -f $tmpfile' EXIT
        kubectl get pods --all-namespaces --no-headers | egrep -v 'Running|Completed' | awk '{print "kubectl describe pod " $2 " --namespace="$1";"}' > $tmpfile
        get_log_by_cmd $temp_dir pod_description "sh $tmpfile"
        rm -f $tmpfile
        trap - EXIT

        echo
        echo Collecting logs for down pods...
        echo ------------------------
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
        get_log_by_cmd $temp_dir log_for_down_pods "sh $TmpFileForDownPods"
        rm -f $TmpFileForDownPods
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
        else
                print_failed_message "failed to collect $name"
        fi
}

get_log_by_cmd(){
	local temp_dir=$1
	local name=$2
	local cmd=$3
	local log_file=$temp_dir"/$name"
	$cmd > $log_file
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


TEMP_DIR=$1    ###sanjitc ####
typeset -fx setup
typeset -fx sanity_checks
#typeset -fx log_collector $TEMP_DIR
typeset -fx log_collector
typeset -fx component_log_collector
typeset -fx check_log_file_exist
typeset -fx get_log_by_cmd
typeset -fx get_container_log_by_name
