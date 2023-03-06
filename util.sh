#!/usr/bin/env bash

ACMESH_HOME="/usr/local/share/acme.sh"
ACMESH="${ACMESH:="$ACMESH_HOME/acme.sh"}"
DEPLOYHOOK="synology_dsm_local"

# dns_api
do_install(){
	if [ ! -d "$ACMESH_HOME" ]; then
		local _dns_api="$1"; shift

		mkdir -p "$ACMESH_HOME"
		mkdir "${ACMESH_HOME}/dnsapi" "${ACMESH_HOME}/deploy"

		wget "https://github.com/acmesh-official/acme.sh/raw/master/acme.sh" -P "${ACMESH_HOME}/"
		wget "https://github.com/acmesh-official/acme.sh/raw/master/dns_api/${_dns_api}.sh" -P "${ACMESH_HOME}/dnsapi/"
		#wget "https://github.com/acmesh-official/acme.sh/raw/master/deploy/synology_dsm.sh" -P "$ACMESH_HOME/deploy/"
		cp "./acme.sh/synology_dsm_local.sh" "${ACMESH_HOME}/deploy/"
	fi
	
	$ACMESH \
		--install \
		--home "$ACMESH_HOME" \
		--no-profile \
		--no-cron "$@"

	return $?
}

# email domain dns_api
do_issue(){
	if [ $# -lt 3 ]; then
		show_help
		return 1
	fi
	local _email="$1"; shift
	local _domain="$2"; shift
	local _dns_api="$3"; shift

	$ACMESH \
		--issue \
		--home "$ACMESH_HOME" \
		--email "$_email" \
		--domain "$_domain" \
		--dns "$_dns_api" "$@"
	
	return $?
}

# domain
do_deploy(){
	local _domain="$1"; shift

	$ACMESH \
		--deploy \
		--home "$ACMESH_HOME" \
		--domain "$_domain" \
		--deploy-hook "$DEPLOYHOOK" "$@"

	return $?
}

# domain
do_renew(){
	local _domain="$1"
}

do_cron_task(){
	local script="$ACMESH --cron --home \"$ACMESH_HOME\""

	# TODO: check for existing task that matches script before installing new task

	synowebapi --exec-fastwebapi api=SYNO.Core.TaskScheduler method=create version=3 \
		type='"script"' \
		name='"Renew certificates with acme.sh"' \
		owner='"root"' \
		extra='{"script":"'"$script"'"}' \
		enable='"true"' \
		schedule='{"date_type":0,"week_day":"0,1,2,3,4,5,6","hour":'$(($RANDOM % 24))',"minute":'$(($RANDOM % 60))',"repeat_hour":0,"repeat_min":0,"last_work_hour":0}'
	
	if [ $? -ne 0 ]; then
		printf "There was an error creating a scheduled task"
		printf "Manually create a Scheduled Task (User-defined script) using the DSM Task Scheduler:"
		printf "    Schedule: Daily @ 00:00"
		printf "    Script: \"%s\"" "$script"
	fi
}

do_quick(){
	printf "Ensure the necessary acme.sh environment variables are set first"
	do_issue "$1" "$2" "$3"
	do_deploy "$2"
	do_cron_task
}

show_help(){
cat << EOF
Commands:
  ${0##*/} install [dns_api]                 Install acme.sh
  ${0##*/} issue <email> <domain> <dns api>  Issue certificate
  ${0##*/} deploy <domain>                   Deploy certificate
  ${0##*/} renew [domain]                    Renew certificate for domain, or all domains if <domain> omitted.
  ${0##*/} quick <email> <domain> <dns api>  Issue, deploy, and install scheduled task to renew all certificates.
  ${0##*/} cron                              Install scheduled task to renew all certificates.
  ${0##*/} acme.sh [args]                    Run acme.sh with [args]

Flags:
    -h, --help                 Show help
    --home                     Path to acme.sh home
EOF
}

while :; do
    case $1 in
        -h|-\?|--help)
            show_help    # Display a usage synopsis.
            exit
            ;;
		# --home)       # Takes an option argument; ensure it has been specified.
        #     if [ "$2" ]; then
        #         ACMESH_HOME=$2
        #         shift
        #     else
        #         die 'ERROR: "--home" requires a non-empty option argument.'
        #     fi
        #     ;;
        # --home=?*)
        #     ACMESH_HOME=${1#*=} # Delete everything up to "=" and assign the remainder.
        #     ;;
        # --home=)         # Handle the case of an empty --home=
        #     die 'ERROR: "--home" requires a non-empty option argument.'
        #     ;;
        # -v|--verbose)
        #     verbose=$((verbose + 1))  # Each -v adds 1 to verbosity.
        #     ;;
        --)              # End of all options.
            shift
            break
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            ;;
        *)               # Default case: No more options, so break out of the loop.
            break
    esac

    shift
done

subcommand=$1; shift  # Remove 'util' from the argument list
case "$subcommand" in
	# Parse options to the install sub command
	install)
		do_install "$@"
		;;
	issue)
		do_issue "$@"
		;;
	deploy)
		do_deploy "$@"
		;;
	renew)
		do_renew "$@"
		;;
	quick)
		do_quick "$@"
		;;
	cron)
		do_cron_task
		;;
	acme)
		$ACMESH --home "$ACMESH_HOME" "$@"
		;;
esac