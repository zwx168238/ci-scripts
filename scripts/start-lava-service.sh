#!/bin/bash
# rm lock
rm /var/run/lava*

services=(ssh postgresql tftpd-hpa apache2 lava-slave lava-coordinator lava-master  lavapdu-listen lavapdu-runner lava-server)

for i in ${services[@]};do
    service $i start
done
