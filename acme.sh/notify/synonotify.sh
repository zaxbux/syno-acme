#!/usr/bin/env bash

# Here is a script to support native Synology notifications.
#
# The System > Certificate notification can be modified to include %SUBJECT% and %CONTENT% placeholders.
#

_SYNO_NOTIFY_BINARY="/usr/syno/bin/synonotify"
_SYNO_NOTIFY_TAG_EVENT="certificate_broken"

synonotify_send() {
  _subject="$1"
  _content="$2"
  _statusCode="$3" #0: success, 1: error 2($RENEW_SKIP): skipped
  _debug "_statusCode" "$_statusCode"

  if [ -n "$_SYNO_NOTIFY_BINARY" ] && ! _exists "$_SYNO_NOTIFY_BINARY"; then
    _err "$_SYNO_NOTIFY_BINARY does not exist"
    return 1
  fi

  local result

  if ! result=$($_SYNO_NOTIFY_BINARY "${_SYNO_NOTIFY_TAG_EVENT}" "{\"%SUBJECT%\":\"$_subject\",\"%CONTENT%\":\"$_content\"}"); then
    _err "synonotify error: $result"
    return 1
  fi

  return 0
}