#!/bin/bash

LVSNAPTAB=/root/bin/lvsnaptab.conf


case "$1" in
        start)
                mkdir -p /mnt/snapshot
				# Services to stop before taking the snapshot
				/etc/init.d/mysql stop
				
				sync
                
				/root/bin/lvsnap.sh start $LVSNAPTAB backuppc-
				# Services to restart after taking the snapshot
				/etc/init.d/mysql start

                ;;
        stop)
                /root/bin/lvsnap.sh stop $LVSNAPTAB backuppc-

                ;;
esac

