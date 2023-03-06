#!/usr/bin/env bash

# Here is a script to deploy certificate to Synology DSM.
#
# This script must be run as root, since the 'synowebapi' binary requires root permissions.
#
# It requires following environment variables:
#
# DEPLOY_SYNO_Create      - Create certificate if it does not exist. DEPLOY_SYNO_Certificate is required.
# DEPLOY_SYNO_Certificate - Certificate to target for replacement (description or id)
#
# Dependencies:
# -------------
# - jq and curl
#
#returns 0 means success, otherwise error.

########  Public functions #####################

#domain keyfile certfile cafile fullchain
synology_dsm_local_deploy() {
  JQ_BINARY="/bin/jq"
  SYNO_WEBAPI_BINARY="/usr/syno/bin/synowebapi"
  SYNO_WEBAPI_CORE_CERTICIATE="SYNO.Core.Certificate"
  SYNO_WEBAPI_CORE_CERTICIATE_CRT="SYNO.Core.Certificate.CRT"

  _cdomain="$1"
  _ckey="$2"
  _ccert="$3"
  _cca="$4"
  _cid=""
  _cdesc=""
  _cdefault="false"

  _debug _cdomain "$_cdomain"
  _debug _ckey "$_ckey"
  _debug _ccert "$_ccert"
  _debug _cca "$_cca"

  _getdeployconf DEPLOY_SYNO_Create
  _getdeployconf DEPLOY_SYNO_Certificate

  _debug DEPLOY_SYNO_Certificate "${DEPLOY_SYNO_Certificate:-}"

  # shellcheck disable=SC1003 # We are not trying to escape a single quote
  if printf "%s" "$DEPLOY_SYNO_Certificate" | grep '\\'; then
    _err "Do not use a backslash (\) in your certificate description"
    return 1
  fi

  _debug "Fetching certificates"
  
  response=$(_syno_webapi_exec_jq '.data.certificates[]' $SYNO_WEBAPI_CORE_CERTICIATE_CRT 1 list)
  _debug3 response "$response"

  # Find by ID
  _certificate=$(echo "$response" | ${JQ_BINARY} -r --arg ID "$DEPLOY_SYNO_Certificate" 'select(.id==$ID)')

  if [ -z "$_certificate" ]; then
    # Find by description
    _certificate=$(echo "$response" | ${JQ_BINARY} -r --arg DESC "$DEPLOY_SYNO_Certificate" 'select(.desc==$DESC)')

    if [ -z "$_certificate" ]; then
      _debug "Certificate [$DEPLOY_SYNO_Certificate] does not exist"

      if [ -z "${DEPLOY_SYNO_Create:-}" ]; then
        _err "Certificate does not exist and \$DEPLOY_SYNO_Create is not set"
        return 1
      else
        _cdesc="$DEPLOY_SYNO_Certificate"
      fi
    else
      _cdesc=$(echo "$_certificate" | ${JQ_BINARY} -r '.desc')
      _debug2 "Certificate exists [desc=$DEPLOY_SYNO_Certificate]"
    fi
  else
    _debug2 "Certificate exists [id=$DEPLOY_SYNO_Certificate]"
  fi
  
  if [ -n "$_certificate" ]; then
    _cid=$(echo "$_certificate" | ${JQ_BINARY} -r '.id')
    _cdefault=$(echo "$_certificate" | ${JQ_BINARY} -r '.is_default')

    if [ -n "$_cdesc" ]; then
      # If certificate was found using description, save the ID
      _savedeployconf DEPLOY_SYNO_Certificate "$_cid"
    fi
  fi

  _debug2 default "Certificate default [$_cdefault]"

  _info "Generate form POST request"

  #declare -A params

  params=("key_tmp=\"$_ckey\"" "cert_tmp=\"$_ccert\"" "inter_cert_tmp=\"$_cca\"" "as_default=\"$_cdefault\"")
  #params[key_tmp]="$_ckey"
  #params[cert_tmp]="$_ccert"
  #params[inter_cert_tmp]="$_cca"
  #params[as_default]="$_cdefault"

  if [ -n "$_certificate" ]; then
    params+=( "id=\"$_cid\"" )
    params+=( "desc=\"$_cdesc\"" )
    #params[id]="$_cid"
  else
    if [ -n "$SYNO_DEPLOY_Create" ]; then
      #params+=( "desc=\"$(printf "%q" "$_cdesc")\"" )
      params+=( "desc=\"$_cdesc\"" )
      #params[desc]="$_cdesc"
    fi
  fi

  _info "Importing certificate"
  _debug3 params "${params[@]}"
  #param_str="$(for k in "${!params[@]}"; do printf "%s=\"%s\" " "${k@Q}" "${params[$k]@Q}" ; done)"
  #param_str="$(for k in "${!params[@]}"; do printf "%s=%s " "${k}" "${params[$k]@Q}" ; done)"
  #_debug3 "params: ${param_str}"
  response="$(_syno_webapi_exec $SYNO_WEBAPI_CORE_CERTICIATE 1 import "${params[@]}")"
  #response="$(_syno_webapi_exec $SYNO_WEBAPI_CORE_CERTICIATE 1 import ${param_str})"
  response_status=$?
  _debug3 response "$response"
  
  error_code=$(echo "$response" | ${JQ_BINARY} -r '.error.code')

  if [ 0 == $response_status ] && [ "null" == "$error_code" ]; then
    _info "httpd restarted [$(echo "$response" | ${JQ_BINARY} -r '.data.restart_httpd')]"

    if [ -n "$DEPLOY_SYNO_Create" ] && [ -z "$_certificate" ]; then
      # Store certificate ID if the certificate was created during this import
      _cid=$(echo "$response" | ${JQ_BINARY} -r '.data.id')
      _savedeployconf DEPLOY_SYNO_Certificate "$_cid"

      _info "Certificate created [id=$_cid]"
    else
      _info "Certificate imported [id=$_cid]"
    fi

    return 0
  else
    case $error_code in
      5510)
        _err "synowebapi error [5510]: Illegal certificate file"
        ;;
      5511)
        _err "synowebapi error [5511]: Illegal key file"
        ;;
      5512)
        _err "synowebapi error [5512]: Illegal intermediate file"
        ;;
      *)
        _err "Certificate import error [code=]"
        ;;
    esac
    return 1
  fi
}

_syno_webapi_exec() {
  # API
  # Example: SYNO.API.Info
  local _api="$1"; shift
  # Version
  # Example: 1
  local _version="$2"; shift
  # Method
  # Example: query
  local _method="$3"; shift
  #shift 3
  # Additional JSON parameters
  #local _param=`echo "$@"`
  #local _param=("$@")

  local _response
  _response="$(${SYNO_WEBAPI_BINARY} --exec-fastwebapi api="$_api" method="$_method" version="$_version" "$@")"

  if [ 0 != $? ]; then
    _err "synowebapi error: $_response"
    return 1
  fi

  local _success
  _success=$(echo "$_response" | ${JQ_BINARY} -r '.success')
  echo "$_response"
  
  if [ "true" != "$_success" ]; then
    return 1
  fi
  return 0
}

_syno_webapi_exec_jq() {
  local _filter="$1"
  shift 1

  local _response
  _response="$(_syno_webapi_exec "$@")"
  if [ 0 != $? ]; then
    return 1
  fi
  
  local _filtered
  _filtered=$(echo "$_response" | ${JQ_BINARY} -r "$_filter")
  echo "$_filtered"
  return 0
}