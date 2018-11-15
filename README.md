# ICP4D Serviceability CLI Tool

icp4d_tools.sh is a command line utlity to host all of the troubleshooting and serviceability tooling around ICP4D

```
Usage:
./icp4d_tools.sh [OPTIONS]

  OPTIONS:
       --preinstall: Run pre-installation requirements checker (CPU, RAM, and Disk space, etc.)
       --health: Run post-installation cluster health checker
       --collect=smart|standard: Run log collection tool to collect diagnostics and logs files from every pod/container. Default is smart
          --component=db2,dsx: Run DB2 Hand log collection,DSX Diagnostics logs collection. Works with --collect=standard option
          --persona=c,a,o: Runs a focused log collection from specific pods related to a personas Collect, Organize and Analyze. Works with --collect=standard option
          --line=N: Capture N number of rows from pod log
       --help: Prints this message

  EXAMPLES:
      ./icp4d_tools.sh --preinstall
      ./icp4d_tools.sh --health
      ./icp4d_tools.sh --collect=smart
      ./icp4d_tools.sh --collect=standard --component=db2,dsx
      ./icp4d_tools.sh --collect=standard --persona=c,a
```

