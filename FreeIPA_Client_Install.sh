#!/bin/bash
#AAA权限管理客户端安装(freeipa-client + auditd + wazuh-agent)
 
set -e
 
#检查命令是否存在
command_exists() {
    command -v "$@" > /dev/null 2>&1
}
 
#判断系统发行版本
if [ -r /etc/os-release ];then
    lsb_dist="$(. /etc/os-release && echo "$ID")"
else
    echo "未找到文件:/etc/os-release，无法判断系统版本!"
    exit 0
fi
 
#修改主机名
if ! echo ${HOSTNAME} | grep ".ipa-demo.com" >/dev/null;then
    hostnamectl set-hostname ${HOSTNAME,,}.ipa-demo.com
fi
 
#安装freeipa-client、auditd、wazuh-agent
export WAZUH_MANAGER_IP='x.x.x.x'
case "$lsb_dist" in
    ubuntu)
        apt-get -qq update
        if ! command_exists expect;then
            apt-get install -qq -y expect >/dev/null
        fi
        DEBIAN_FRONTEND=noninteractive apt-get install -qq -y freeipa-client auditd >/dev/null
        curl -so /tmp/wazuh-agent.deb https://packages.wazuh.com/3.x/apt/pool/main/w/wazuh-agent/wazuh-agent_3.11.4-1_amd64.deb
        dpkg -i /tmp/wazuh-agent.deb >/dev/null
        rm -rf /tmp/wazuh-agent.deb
        ;;
    centos|rhel)
        yum -q clean all
        yum -q makecache
        if ! command_exists expect;then
            yum install -y expect >/dev/null
        fi
        yum install -q -y freeipa-client audit >/dev/null
        yum install -q -y https://packages.wazuh.com/3.x/yum/wazuh-agent-3.11.4-1.x86_64.rpm >/dev/null
        ;;
    *)
        echo "系统版本为:$lsb_dist,暂不支持!"
        exit 0
        ;;
esac
 
#配置freeipa-client
HOST_NAME=`hostname`
DOMAIN="ipa-demo.com"
REALM="IPA-DEMO.COM"
IPA_SERVER="ipa.ipa-demo.com"
KRB5_CONF="/etc/krb5.conf"
SSSD_CONF="/etc/sssd/sssd.conf"
PAM_CONF="/etc/pam.d/common-session"
 
expect<<-EOF
spawn ipa-client-install --hostname=$HOST_NAME --domain=$DOMAIN --realm=$REALM --server=$IPA_SERVER --mkhomedir
expect "IPA client is already configured on this system" {send_user "\n";exit 1}
expect {
        "Proceed with fixed values and no DNS discovery" {send "yes\r";exp_continue}
        "Continue to configure the system with these values" {send "yes\r";exp_continue}
        "User authorized to enroll computers" {send "******\r";exp_continue}
        "Password" {send "*******\r"}
}
expect "Kerberos authentication failed" {expect eof;exit 1}
expect "Client configuration complete" {expect eof;exit 0}
expect eof
EOF
expect_return_value=$?
echo "expect return value:$expect_return_value"
 
if [ $expect_return_value -eq 0 ];then
    sed -i '/^\[sssd\]/i\
krb5_use_enterprise_principal = True\
ignore_group_members = True\
override_shell = /bin/bash' $SSSD_CONF
    service sssd restart
fi
 
if [ "$lsb_dist" = "ubuntu" ];then
    if ! egrep "^[^#]" $PAM_CONF | grep "pam_mkhomedir.so" >/dev/null;then
        echo "session required pam_mkhomedir.so" >> $PAM_CONF
    fi
fi
 
#添加Auditd审计规则
AUDIT_RULE_FILE="/etc/audit/rules.d/audit.rules"
rules=`auditctl -l`
if [ -r $AUDIT_RULE_FILE ];then
    if ! echo "$rules" | grep "audit-wazuh-c" >/dev/null;then
        echo "-a exit,always -F auid!=-1 -F arch=b32 -S execve -k audit-wazuh-c" >> $AUDIT_RULE_FILE
        echo "-a exit,always -F auid!=-1 -F arch=b64 -S execve -k audit-wazuh-c" >> $AUDIT_RULE_FILE
        auditctl -R $AUDIT_RULE_FILE
    fi
else
    echo "未找到文件:$AUDIT_RULE_FILE"
fi
