#!/bin/sh

# Login and get token

TMPL_LOGIN=$(cat << EOF
{
    "jsonrpc": "2.0",
    "method": "user.login",
    "params": {
        "user": "${ZBX_LOGIN:-Admin}",
        "password": "${ZBX_PASSWORD:-zabbix}"
    },
    "id": 1,
    "auth": null
}
EOF
)

TOKEN=$(curl -s -X POST -H 'Content-Type: application/json-rpc' -d "$TMPL_LOGIN" http://$ZBX_API_URL/api_jsonrpc.php | jq -r '.result')

# Find out default node hostid

TMPL_HOSTS=$(cat << EOF
{
    "jsonrpc": "2.0",
    "method": "host.get",
    "params": {
        "output": [
            "hostid"
        ],
        "filter": {
            "host": "Zabbix server"
        }
    },
    "id": 2,
    "auth": "$TOKEN"
}
EOF
)

HOST_ID=$(curl -s -X POST -H 'Content-Type: application/json-rpc' -d "$TMPL_HOSTS" http://$ZBX_API_URL/api_jsonrpc.php | jq '.result[0]' | jq -r '.hostid')

# Ensure host monitoring is enabled

TMPL_MONIT_CHECK=$(cat << EOF
{
    "jsonrpc": "2.0",
    "method": "host.update",
    "params": {
        "hostid": "$HOST_ID",
        "status": 0
    },
    "auth": "$TOKEN",
    "id": 1
}
EOF
)

curl -s -X POST -H 'Content-Type: application/json-rpc' -d "$TMPL_MONIT_CHECK" http://$ZBX_API_URL/api_jsonrpc.php | jq

# Loop over all hosts in file

while read EP; do

# Check if web scenario already exist

TMPL_VHOST_CHECK=$(cat << EOF
{
    "jsonrpc": "2.0",
    "method": "httptest.get",
    "params": {
        "output":
        [
            "httptestid"
        ],
        "filter": {
            "name": "$EP check"
        }
    },
    "auth": "$TOKEN",
    "id": 1
}
EOF
)

IF_VHOST_EXISTS=$(curl -s -X POST -H 'Content-Type: application/json-rpc' -d "$TMPL_VHOST_CHECK" http://$ZBX_API_URL/api_jsonrpc.php | jq ".result[0]" | jq -r ".httptestid")

if [ $IF_VHOST_EXISTS = "null" ]
then
TMPL_VHOST_ADD=$(cat << EOF
{
    "jsonrpc": "2.0",
    "method": "httptest.create",
    "params": {
        "name": "$EP check",
        "hostid": "$HOST_ID",
        "delay": "${ZBX_WEB_DELAY:-60}",
        "timeout": "${ZBX_WEB_TIMEOUT:-15}",
        "steps": [
            {
                "name": "Homepage",
                "url": "http://$EP",
                "status_codes": 200,
                "no": 1
            }
        ]
    },
    "auth": "$TOKEN",
    "id": 1
}
EOF
)
curl -s -X POST -H 'Content-Type: application/json-rpc' -d "$TMPL_VHOST_ADD" http://$ZBX_API_URL/api_jsonrpc.php
else
echo "'$EP check' already exists"
fi

# Check if web scenario trigger already exist

TMPL_TRIGGER_CHECK=$(cat << EOF
{
    "jsonrpc": "2.0",
    "method": "trigger.get",
    "params": {
        "output": [
            "triggerid"
        ],
        "filter": {
            "description": "$EP unreachable"
        }
    },
    "auth": "$TOKEN",
    "id": 1
}
EOF
)

IF_TRIGGER_EXISTS=$(curl -s -X POST -H 'Content-Type: application/json-rpc' -d "$TMPL_TRIGGER_CHECK" http://$ZBX_API_URL/api_jsonrpc.php | jq ".result[0]" | jq -r ".triggerid")

if [ $IF_TRIGGER_EXISTS = "null" ]
then
TMPL_TRIGGER_ADD=$(cat << EOF
{
    "jsonrpc": "2.0",
    "method": "trigger.create",
    "params": {
        "description": "$EP unreachable",
        "expression": "{Zabbix server:web.test.fail[$EP check].min(2m)}<>0",
        "priority": 4
    },
    "auth": "$TOKEN",
    "id": 1
}
EOF
)
curl -s -X POST -H 'Content-Type: application/json-rpc' -d "$TMPL_TRIGGER_ADD" http://$ZBX_API_URL/api_jsonrpc.php
else
echo "'$EP trigger' already exists"
fi

done < endpoints.list

