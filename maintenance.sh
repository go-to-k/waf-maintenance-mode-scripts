#!/bin/bash
set -eu

iplist_file="./iplist_waf.txt"
iplist_max=5

CFN_TEMPLATE="./waf.yml"
CFN_REGION="us-east-1"
CFN_STACK_NAME="WafIp"

CFN_WAFWebACLMetricName="WafIpWebacl"
CFN_ScopeType="CLOUDFRONT"

MaintenanceMode=""

while getopts m: OPT; do
    case $OPT in
        m)
            MaintenanceMode="$OPTARG"
            ;;
    esac
done


if [ -z ${MaintenanceMode} ] \
|| [ "${MaintenanceMode}" != "on" -a "${MaintenanceMode}" != "off" ]; then
  echo "-m(maintenance mode): on/off" 
  exit 1
fi


cnt=0

for ip in `cat ${iplist_file} | tr -d " \t" | grep -v "^#" | sed -e "s/\([^#]*\)#.*$/\1/g"`
do
  if [ -n "${ip}" ]; then
    let cnt++
    eval CFN_CIDR${cnt}="${ip}"
  fi

  if [ $cnt -ge $iplist_max ]; then
    echo "${iplist_max}個の制限を超えたのでここまでのIPを登録します。"
    echo "最後のIP: ${ip}"
    break
  fi
done

opt_param=""

for i in `seq 1 $iplist_max`
do
  if [ $i -gt $cnt ]; then
    eval CFN_CIDR${i}=""
  fi
  
  opt_param="${opt_param} CIDR${i}=$(eval echo '$'CFN_CIDR${i})"  
done


aws cloudformation deploy \
    --template-file ${CFN_TEMPLATE} \
    --region ${CFN_REGION} \
    --stack-name ${CFN_STACK_NAME} \
    --no-fail-on-empty-changeset \
    --parameter-overrides \
    WAFWebACLMetricName=${CFN_WAFWebACLMetricName} \
    ScopeType=${CFN_ScopeType} \
    MaintenanceMode=${MaintenanceMode} \
    ${opt_param}
