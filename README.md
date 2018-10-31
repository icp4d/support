# icp4d-serviceability-cli

icp4d_tools.sh is a command line utlity to host all of the troubleshooting and serviceability tooling around ICP4D

```
Usage:
./icp4d_tools.sh [OPTIONS]

  OPTIONS:
      -i, --interactive: Run the tool in an interactive mode
      -p, --preinstall: Run pre-installation requirements checker (CPU, RAM, and Disk space, etc.)
      -h, --health: Run post-installation cluster health checker
      -c, --collect=smart|standard: Run log collection tool to collect diagnostics and logs files from every pod/container. Default is smart
          --collectdb2: Run DB2 Hand log collection, works with --collect=standard option
          --collectdsx: Run DSX Diagnostice log collection, works with --collect=standard option
      -h, --help: Prints this message

  EXAMPLES:
      ./icp4d_tools.sh -preinstall
      ./icp4d_tools.sh --health
      ./icp4d_tools.sh --collect=smart
      ./icp4d_tools.sh --collect=standard --collectdb2
```

