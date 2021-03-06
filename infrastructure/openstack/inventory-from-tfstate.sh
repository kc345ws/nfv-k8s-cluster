#!/bin/bash -e
#
# Generate an ansible inventory file for kubespray...
#
# Assumptions:
# worker resources match: /^openstack_compute_instance_v2.worker/
# master resources match: /^openstack_compute_instance_v2.master/
#

die() {
	echo "$*"
	exit 1
}

if ! command -v jq > /dev/null ; then
	die "dependency jq missing. please install jq."
fi

tfstate="$1" ; shift

[ -z "$tfstate" ] && die "please specify tfstate file as first argument."
[ ! -r "$tfstate" ] && die "tfstate [$tfstate] is not readable."

worker_count=$( jq -r '.modules[].resources| to_entries | 
	map(select(.key|match("^openstack_compute_instance_v2.worker")))|length' "$tfstate")

master_count=$( jq -r '.modules[].resources| to_entries | 
	map(select(.key|match("^openstack_compute_instance_v2.master")))|length' "$tfstate")

jq --argjson idx 0 -r '.modules[].resources| to_entries | 
	map(select(.key|match("^openstack_compute_instance_v2.worker")))|
	keys[] as $i |
	{
		idx: $i,
		resource: (.[$i].key),
		ip: (.[$i].value.primary.attributes.access_ip_v4),
	} |
	"# resource: "+.resource,
	"worker"+(.idx|tostring)+" ansible_user=ubuntu ansible_host="+.ip,""
' "$tfstate"

jq --argjson idx 0 -r '.modules[].resources| to_entries | 
	map(select(.key|match("^openstack_compute_instance_v2.master")))|
	keys[] as $i |
	{
		idx: $i,
		resource: (.[$i].key),
		ip: (.[$i].value.primary.attributes.access_ip_v4),
	} |
	"# resource: "+.resource,
	"master"+(.idx|tostring)+" ansible_user=ubuntu ansible_host="+.ip+" ip="+.ip,""
' "$tfstate"

printf "[kube-master]\n"
idx=-1
while [ $(( ++idx )) -lt $master_count ]; do
	printf "master$idx\n"
done


printf "\n[etcd]\n"
idx=-1
while [ $(( ++idx )) -lt $master_count ]; do
	printf "master$idx\n"
done


printf "\n[kube-node]\n"
idx=-1
while [ $(( ++idx )) -lt $worker_count ]; do
	printf "worker$idx\n"
done

cat <<EOF

[k8s-cluster:children]
kube-node
kube-master
EOF
