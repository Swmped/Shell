#!/bin/bash
#安装auditd和wazuh-agent
set -e

base_path=$( cd `dirname "${BASH_SOURCE[0]}"` && pwd )
#判断系统发行版本
if [ -r /etc/os-release ];then
    lsb_dist="$(. /etc/os-release && echo "$ID")"
else
    echo "未找到文件:/etc/os-release，无法判断系统发行版本!安装失败!"
    exit 0
fi

export WAZUH_MANAGER="$1"

#添加auditd命令审计规则
add_audit_rules(){
	AUDIT_RULE_FILE="/etc/audit/rules.d/audit.rules"
	rules=`auditctl -l`
        if ! echo "${rules}" | grep "audit-wazuh-c" >/dev/null;then
                echo "-a exit,always -F auid!=-1 -F arch=b32 -S execve -k audit-wazuh-c" >> ${AUDIT_RULE_FILE}
                echo "-a exit,always -F auid!=-1 -F arch=b64 -S execve -k audit-wazuh-c" >> ${AUDIT_RULE_FILE}
                auditctl -R ${AUDIT_RULE_FILE} >/dev/null
        fi
}

#安装
case "$lsb_dist" in
    ubuntu)
        apt-get -qq update
        apt-get install -qq -y auditd >/dev/null
	add_audit_rules
        curl -so /tmp/wazuh-agent.deb https://packages.wazuh.com/3.x/apt/pool/main/w/wazuh-agent/wazuh-agent_3.11.4-1_amd64.deb
        dpkg -i /tmp/wazuh-agent.deb >/dev/null
        rm -rf /tmp/wazuh-agent.deb
	auditd_status=`dpkg -s auditd 2>/dev/null | grep Status | awk -F ":" '{print $2}'`
	wazuh_status=`dpkg -s wazuh-agent 2>/dev/null | grep Status | awk -F ":" '{print $2}'`
	if [ "${auditd_status}" = " install ok installed" ] && [ "${wazuh_status}" = " install ok installed" ];then
		echo "安装完成"
	else
		echo "安装失败"
	fi
        ;;
    centos|rhel)
        yum -q clean all
        yum -q makecache &>/dev/null
        yum install -q -y audit >/dev/null
	add_audit_rules
        yum install -q -y https://packages.wazuh.com/3.x/yum/wazuh-agent-3.11.4-1.x86_64.rpm >/dev/null
	if rpm -q audit && rpm -q wazuh-agent;then
		echo "安装完成"
	else
		echo "安装失败"
	fi
        ;;
    *)
        echo "系统版本为:$lsb_dist,不支持,安装失败！"
        ;;
esac

#rm -rf ${base_path}/install.sh
