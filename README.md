# syno-acme

Automatically renew Let's Encrypt certificates for your Synology NAS.

This implementation uses the `synowebapi` command to install and replace certificates.

## Background

Some of the other methods that I found relied on the HTTP API for DSM to install certificates.
I often ran into issues with using the correct HTTP(S) ports, insecure HTTPS warnings, and 2FA interference.
Since I'm always going to be renewing certificates directly on the NAS and not remotely, I don't need any of the DSM HTTP APIs to update and restart services. I also didn't want to setup an entire docker container just to renew a certificate. After analyzing the binary and libraries used, I determined the necessary parameters to create certificates with the `synowebapi` command and wrote a custom `acme.sh` deploy hook (based on the existing `synology_dsm` hook).

# Install

## Automatic

> Work in progress...

## Manual

> This method assumes that
>  a) you have `acme.sh` installed; and
>  b) have issued a certificate for the domain you're using.

 1. Copy the [`acme.sh/deploy/synology_dsm_local.sh`](./acme.sh/deploy/synology_dsm_local.sh) script to the `deploy` directory inside your `acme.sh` home directory.

 2. Deploy your certificate using the custom deploy hook:

    ```
    export DEPLOY_SYNO_Create=1
    export DEPLOY_SYNO_Certificate="My Certificate"
    acme.sh --deploy --home <acme.sh home> --domain <domain> --deploy-hook synology_dsm_local
    ```

 3. Create a scheduled task in DSM:
    ```
    <acme.sh home>/acme.sh --cron --home <acme.sh home>
    ```

### Notifications

1.  Copy the [`acme.sh/notify/synonotify.sh`](./acme.sh/notify/synonotify.sh) script to the `notify` directory inside your `acme.sh` home directory.
2.  Set a notification using the custom [notify](https://github.com/acmesh-official/acme.sh/wiki/notify) hook:

    ```
    acme.sh --set-notify --notify-hook synonotify
    ```

    Alternatively, `ssmtp` can be used (it will use the mail settings from DSM):

    ```
    export MAIL_BIN="/bin/ssmtp"
    export MAIL_TO="you@example.com"
    acme.sh --set-notify --notify-hook mail
    ```