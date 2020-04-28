#!/bin/bash
#安装auditd和wazuh-agent
set -e

base_path=$( cd `dirname "${BASH_SOURCE[0]}"` && pwd )
log="/tmp/wazuh_install.log"

> ${log}

#判断系统发行版本
if [ -r /etc/os-release ];then
    lsb_dist="$(. /etc/os-release && echo "$ID")"
else
    echo "未找到文件:/etc/os-release，无法判断系统发行版本!安装失败!"
    exit 0
fi

export WAZUH_MANAGER="$1"
if ! ping -c 1 ${WAZUH_MANAGER} &>>${log};then
	echo "无法访问${WAZUH_MANAGER},请检查网络!"
	exit 0
fi


#获取系统信息
get_system_info(){
	echo "Hostname: `hostname`"
	echo "Serial Number: `dmidecode -t system | grep "Serial Number" | awk -F ":" '{print $2}'`"
	for netcard in $(ls /sys/class/net)
	do
		if ! echo ${netcard} | grep -E "lo|docker0|virbr0|veth" &>/dev/null;then
			echo "HWaddr-${netcard}: `cat /sys/class/net/${netcard}/address`"
		fi
	done
}

#配置auditd
audit_configure(){
	AUDIT_RULE_FILE="/etc/audit/rules.d/audit.rules"
	rules=`auditctl -l`
        if ! echo "${rules}" | grep "audit-wazuh-c" &>>${log};then
                echo "-a exit,always -F auid!=-1 -F arch=b32 -S execve -k audit-wazuh-c" >> ${AUDIT_RULE_FILE}
                echo "-a exit,always -F auid!=-1 -F arch=b64 -S execve -k audit-wazuh-c" >> ${AUDIT_RULE_FILE}
		echo "-a exit,always -F uid>=0 -F auid=-1 -F arch=b32 -S execve -k audit-wazuh-c" >> ${AUDIT_RULE_FILE}
		echo "-a exit,always -F uid>=0 -F auid=-1 -F arch=b64 -S execve -k audit-wazuh-c" >> ${AUDIT_RULE_FILE}
                auditctl -R ${AUDIT_RULE_FILE} &>>${log}
        fi
}

#安装
case "$lsb_dist" in
    ubuntu)
        apt-get update &>>${log}
        apt-get install -y auditd &>>{log}
	audit_configure
	curl -so /tmp/wazuh-agent.deb https://packages.wazuh.com/3.x/apt/pool/main/w/wazuh-agent/wazuh-agent_3.12.2-1_amd64.deb
        dpkg -i /tmp/wazuh-agent.deb &>>${log}
        rm -rf /tmp/wazuh-agent.deb
	auditd_status=`dpkg -s auditd 2>>${log} | grep Status | awk -F ":" '{print $2}'`
	wazuh_status=`dpkg -s wazuh-agent 2>>${log} | grep Status | awk -F ":" '{print $2}'`
	if [ "${auditd_status}" = " install ok installed" ] && [ "${wazuh_status}" = " install ok installed" ];then
		echo "安装完成"
		get_system_info
	else
		echo "安装失败"
	fi
        ;;
    centos|rhel)
        yum clean all &>>${log}
        yum makecache &>>${log}
        yum install -y audit &>>${log}
	audit_configure
        yum install -y https://packages.wazuh.com/3.x/yum/wazuh-agent-3.12.2-1.x86_64.rpm &>>${log}
	if rpm -q audit && rpm -q wazuh-agent;then
		echo "安装完成"
		get_system_info
	else
		echo "安装失败"
	fi
        ;;
    *)
        echo "系统版本为:$lsb_dist,不支持,安装失败！"
        ;;
esac
