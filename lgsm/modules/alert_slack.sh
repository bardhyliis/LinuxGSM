#!/bin/bash
# LinuxGSM alert_slack.sh module
# Author: Daniel Gibbs
# Contributors: https://linuxgsm.com/contrib
# Website: https://linuxgsm.com
# Description: Sends Slack alert.

moduleselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

json=$(
	cat << EOF
{
	"attachments": [
		{
			"color": "${alertcolourhex}",
			"blocks": [
				{
					"type": "header",
					"text": {
						"type": "mrkdwn",
						"text": "${alerttitle}",
						"emoji": true
					}
				},
				{
					"type": "divider"
				},
				{
					"type": "section",
					"text": {
						"type": "mrkdwn",
						"text": "*Server Name*\n${servername}"
					}
				},
				{
					"type": "section",
					"text": {
						"type": "mrkdwn",
						"text": "*Information*\n${alertmessage}"
					}
				},
				{
					"type": "section",
					"fields": [
						{
							"type": "mrkdwn",
							"text": "*Game*\n${gamename}"
						},
						{
							"type": "mrkdwn",
							"text": "*Server IP*\n\`${alertip}:${port}\`"
						},
						{
							"type": "mrkdwn",
							"text": "*Hostname*\n${HOSTNAME}"
						},
						{
							"type": "mrkdwn",
							"text": "*Server Time*\n$(date)"
						}
					],
					"accessory": {
						"type": "image",
						"image_url": "${alerticon}",
						"alt_text": "cute cat"
					}
				},
				{
					"type": "context",
					"elements": [
						{
							"type": "image",
							"image_url": "https://raw.githubusercontent.com/${githubuser}/${githubrepo}/${githubbranch}/lgsm/data/alert_discord_logo.jpg",
							"alt_text": "Ray-Hosting icon"
						},
						{
							"type": "plain_text",
							"text": "Sent by Ray-Hosting ${version}",
							"emoji": true
						}
					]
				}
			]
		}
	]
}
EOF
)

if [ -n "${querytype}" ]; then
	json+=$(
		cat << EOF
				{
					"type": "section",
					"text": {
						"type": "mrkdwn",
						"text": "*Is my Game Server Online?*\n<https://ismygameserver.online/${imgsoquerytype}/${alertip}:${queryport}|Check here>"
					}
				},
EOF
	)
fi

if [ -n "${alerturl}" ]; then
	json+=$(
		cat << EOF
				{
					"type": "section",
					"text": {
						"type": "mrkdwn",
						"text": "*More info*\n<${alerturl}|${alerturl}>"
					}
				},
EOF
	)
fi

json+=$(
	cat << EOF
{
	"attachments": [
		{
			"color": "${alertcolourhex}",
			"blocks": [
				{
					"type": "header",
					"text": {
						"type": "mrkdwn",
						"text": "${alerttitle}",
						"emoji": true
					}
				},
				{
					"type": "divider"
				},
				{
					"type": "section",
					"text": {
						"type": "mrkdwn",
						"text": "*Server Name*\n${servername}"
					}
				},
				{
					"type": "section",
					"text": {
						"type": "mrkdwn",
						"text": "*Information*\n${alertmessage}"
					}
				},
				{
					"type": "section",
					"fields": [
						{
							"type": "mrkdwn",
							"text": "*Game*\n${gamename}"
						},
						{
							"type": "mrkdwn",
							"text": "*Server IP*\n\`${alertip}:${port}\`"
						},
						{
							"type": "mrkdwn",
							"text": "*Hostname*\n${HOSTNAME}"
						},
						{
							"type": "mrkdwn",
							"text": "*Server Time*\n$(date)"
						}
					],
					"accessory": {
						"type": "image",
						"image_url": "${alerticon}",
						"alt_text": "cute cat"
					}
				},
				{
					"type": "section",
					"text": {
						"type": "mrkdwn",
						"text": "*Server Time*\n${alertmessage}"
					}
				},
				{
					"type": "context",
					"elements": [
						{
							"type": "image",
							"image_url": "https://raw.githubusercontent.com/${githubuser}/${githubrepo}/${githubbranch}/lgsm/data/alert_discord_logo.jpg",
							"alt_text": "Ray-Hosting icon"
						},
						{
							"type": "plain_text",
							"text": "Sent by Ray-Hosting ${version}",
							"emoji": true
						}
					]
				}
			]
		}
	]
}
EOF
)

fn_print_dots "Sending Slack alert"

slacksend=$(curl --connect-timeout 3 -sSL -H "Content-Type: application/json" -X POST -d "$(echo -n "${json}" | jq -c .)" "${slackwebhook}")

if [ "${slacksend}" == "ok" ]; then
	fn_print_ok_nl "Sending Slack alert"
	fn_script_log_pass "Sending Slack alert"
else
	fn_print_fail_nl "Sending Slack alert: ${slacksend}"
	fn_script_log_fail "Sending Slack alert: ${slacksend}"
fi
