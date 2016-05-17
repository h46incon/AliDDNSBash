#!/bin/bash

#Dependences: bind-dig, curl, openssl-util, sort(probably implemented by bash or other shell)

## ===== public =====

## ----- Log level -----
_DEBUG_="1"
_LOG_="1"
_ERR_="1"


## ----- Setting -----
AccessKeyId="testid"
AccessKeySec="testsecret"
DomainRecordId="00000"
DomainRR="www"
DomainName="example.com"
DomainType="A"
# DNS Server for check current IP of the record
# Perferred setting is your domain name service provider
DNSServer="dns9.hichina.com"

# The server address of ALi API
ALiServerAddr="alidns.aliyuncs.com"
# A url provided by a third-party to echo the public IP of host
MyIPEchoUrl="http://members.3322.org/dyndns/getip"

# the generatation a random number can be modified here
rand_num=0
#((rand_num=${RANDOM} * ${RANDOM} * ${RANDOM}))
rand_num=$(openssl rand 16 -hex)


## ===== private =====

## ----- global var -----
declare -A params
_func_ret=""


## ----- Base Util -----
_debug() { ((_DEBUG_)) && echo "> $*"; }
_log() { ((_LOG_)) && echo "* $*"; }
_err() { ((_ERR_)) && echo "! $*"; }

reset_func_ret()
{
	_func_ret=""
}

## ----- params -----

# This function will init all public params EXCLUDE "Signature" and "Value" 
put_params_public()
{
	params["Format"]="JSON"
	params["Version"]="2015-01-09"
	params["AccessKeyId"]="${AccessKeyId}"
	params["SignatureMethod"]="HMAC-SHA1"

	# time stamp
	local time_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	params["Timestamp"]="${time_utc}"
	_debug time_stamp: ${params[Timestamp]}

	params["SignatureVersion"]="1.0"

	# random number
	_debug rand_num: ${rand_num}
	params["SignatureNonce"]="${rand_num}"
}


# @Param1: New IP address
put_params_UpdateDomainRecord()
{
	params["Action"]="UpdateDomainRecord"
	params["RR"]="${DomainRR}"
	params["RecordId"]="${DomainRecordId}"
	params["Type"]="${DomainType}"
	params["Value"]="${1}"
}

put_params_DescribeDomainRecords()
{
	params["Action"]="DescribeDomainRecords"
	params["DomainName"]=${DomainName}
}

# @Param1: Signature
put_params_Signature()
{
	params["Signature"]="${1}"
}

pack_params()
{
	reset_func_ret

	local key_enc=""
	local val_enc=""

	local ret=""
	for key in "${!params[@]}"
	do
		rawurl_encode "${key}"
		key_enc=${_func_ret}
		rawurl_encode "${params[${key}]}"
		val_enc=${_func_ret}
		
		ret+="${key_enc}""=""${val_enc}""&"
	done

	#delete last "&"
	_func_ret=${ret%"&"}
}


# ----- Other utils ----- 

get_my_ip()
{
	reset_func_ret
	local my_ip=$(curl ${MyIPEchoUrl} --silent --connect-timeout 10)

	#echo ${my_ip}
	_func_ret=${my_ip}
}

get_domain_ip()
{
	reset_func_ret
	local full_domain=""
	if [ -z "${DomainRR}" ] || [ "${DomainRR}" == "@" ]; then 
		full_domain=${DomainName}
	else
		full_domain=${DomainRR}.${DomainName}
	fi

	local ns_param=""
	if [ -z "${DNSServer}" ] ; then 
		ns_param=""
	else
		ns_param="@""${DNSServer}"
	fi

	_func_ret=$(dig "$ns_param" "${full_domain}" +short)
}

# @Param1: Raw url to be encoded
rawurl_encode() 
{
	reset_func_ret

	local string="${1}"
	local strlen=${#string}
	local encoded=""
	local pos c o
	
	for (( pos=0 ; pos<strlen ; pos++ )); do
		c=${string:$pos:1}
		case "$c" in
			[-_.~a-zA-Z0-9] ) o="${c}" ;;
			* )               printf -v o '%%%02X' "'$c"
		esac
		encoded+="${o}"
	done
	_func_ret="${encoded}" 
}

calc_signature()
{
	reset_func_ret

	# sort keys
	local sorted_keys=( $(
		for el in "${!params[@]}"
		do 
			echo "$el"
		done | LC_COLLATE=C sort
	) )

	# concat keys and values to get query string
	local key_enc=""
	local val_enc=""

	local query_str=""
	for key in "${sorted_keys[@]}"
	do
		rawurl_encode "${key}"
		key_enc=${_func_ret}
		rawurl_encode "${params[${key}]}"
		val_enc=${_func_ret}

		query_str+="${key_enc}""=""${val_enc}""&"
	done
	# delete last "&"
	query_str=${query_str%"&"}
	
	_debug Query String: ${query_str}
	# encode
	rawurl_encode "${query_str}"
	local encoded_str=${_func_ret}

	local str_to_signed="GET&%2F&"${encoded_str}
	local key_sign="${AccessKeySec}""&"

	_func_ret=$(echo -n ${str_to_signed} | openssl dgst -binary -sha1 -hmac ${key_sign} | openssl enc -base64)
}

send_request()
{
	# put signature
	calc_signature
	local signature=${_func_ret}
	put_params_Signature ${signature}

	# pack all params
	pack_params
	local packed_params=${_func_ret}

	local req_url="${ALiServerAddr}""/?""${packed_params}"
	_debug Request addr: ${req_url}

	local respond=$(curl -3 ${req_url} --silent --connect-timeout 10 -w "HttpCode:%{http_code}")
	echo ${respond}
}

describe_record()
{
	put_params_public
	put_params_DescribeDomainRecords

	send_request
}

update_record()
{
	# get ip
	get_my_ip
	local my_ip=${_func_ret}

	# Check if need update
	_debug My IP: ${my_ip}
	if [ -z "${my_ip}" ]; then
		_err Could not get my ip, exitting...
		exit
	fi
	get_domain_ip;
	local domain_ip=${_func_ret}
	_debug Current Domain IP: ${domain_ip}

	if [ "${my_ip}" == "${domain_ip}" ]; then
		_log Need not to update, current IP: ${my_ip}
		exit
	fi

	# init params
	put_params_public
	put_params_UpdateDomainRecord ${my_ip}

	send_request
}


main()
{
	#describe_record
	update_record
}


main



