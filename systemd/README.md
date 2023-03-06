# systemd

## Service

```sh
sudo systemctl daemon-reload
sudo systemctl start acme_letsencrypt
```

## Timer

```sh
sudo systemctl start acme_letsencrypt.timer
sudo systemctl enable acme_letsencrypt.timer
```