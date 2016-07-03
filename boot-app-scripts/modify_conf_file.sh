#!/bin/bash
IFS=$'\n'

ip_addr_file="device_ip_type.txt"

for file in `ls`
do
    [[ $file =~ ".conf" ]] || continue
    target_instance=${file%.*}
    flag=0
    while read line
    do 
        valid=$(echo $line | grep -w $target_instance)
	    if [ ""x != "$valid"x ]; then
	        ip_addr=$(echo $line | awk '{print $3}')
            flag=1
	        break
	    fi
    done < $ip_addr_file
    if [ $flag -eq 1 ]; then
	    device_conf=$target_instance'_ssh.conf'
	    #cp $device_conf  $device_conf".1"
        echo $ip_addr   '  '  $device_conf ' target_instance:' $target_instance
	    sed -i "s/^dummy_ssh_host.*/dummy_ssh_host = $ip_addr/g"  $device_conf
    fi
done



