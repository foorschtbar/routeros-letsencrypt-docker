# Let's Encrypt for RouterOS Webserver/API

[
  ![](https://img.shields.io/docker/v/foorschtbar/routeros-letsencrypt?style=plastic)
  ![](https://img.shields.io/docker/pulls/foorschtbar/routeros-letsencrypt?style=plastic)
  ![](https://img.shields.io/docker/stars/foorschtbar/routeros-letsencrypt?style=plastic)
  ![](https://img.shields.io/docker/image-size/foorschtbar/routeros-letsencrypt?style=plastic)
](https://hub.docker.com/repository/docker/foorschtbar/routeros-letsencrypt)
[
  ![](https://img.shields.io/github/actions/workflow/status/foorschtbar/routeros-letsencrypt-docker/build.yml?branch=master&style=plastic)
  ![](https://img.shields.io/github/languages/top/foorschtbar/routeros-letsencrypt-docker?style=plastic)
  ![](https://img.shields.io/github/last-commit/foorschtbar/routeros-letsencrypt-docker?style=plastic)
  ![](https://img.shields.io/github/license/foorschtbar/routeros-letsencrypt-docker?style=plastic)
](https://github.com/foorschtbar/routeros-letsencrypt-docker)

[![MikroTik](https://i.mt.lv/mtv2/logo.svg)](https://mikrotik.com/)

This Docker container automatically renews certificates from Let's Encrypt, copies them to a MikroTik device running RouterOS, and activates them in the Webserver, API and OpenVPN Server.

* GitHub: [foorschtbar/routeros-letsencrypt-docker](https://github.com/foorschtbar/routeros-letsencrypt-docker)
* Docker Hub: [foorschtbar/routeros-letsencrypt](https://hub.docker.com/r/foorschtbar/routeros-letsencrypt)

## Configuration

* Map a SSH private keyfile for login into RouterOS
* Map a volume/folder to store persistent authorization information between container restarts
* Configure environment variables to controll the automation process:

Name | Default | Description
--- | --- | ---
`ROUTEROS_USER` | _(none)_ | User with policies `ssh, write, ftp, read` 
`ROUTEROS_HOST` | _(none)_ | RouterOS IP or Hostname
`ROUTEROS_SSH_PORT` | `22` | RouterOS SSH Port
`ROUTEROS_PRIVATE_KEY` | _(none)_ | Private Key file to connect to RouterOS (set permissions to 0400!)
`ROUTEROS_DOMAIN` | _(none)_ | Domainname for catch up certs from LEGO Client. Usually the **first** Domain you set in the LEGO_DOMAINS variable
`LEGO_STAGING` | `1` |  Whether to use production or staging LetsEncrypt endpoint. `0` for production, `1` for staging
`LEGO_KEY_TYPE` | `ec384` | Type of key
`LEGO_DOMAINS` | _(none)_ | Domains (delimited by ';' )
`LEGO_EMAIL_ADDRESS` | _(none)_ | Email used for registration and recovery contact.
`LEGO_PROVIDER` | _(none)_ | [DNS Provider](https://go-acme.github.io/lego/dns/). Valid values are: `acmedns`, `alidns`, `arvancloud`, `auroradns`, `autodns`, `azure`, `bindman`, `bluecat`, `checkdomain`, `clouddns`, `cloudflare`, `cloudns`, `cloudxns`, `conoha`, `constellix`, `desec`, `designate`, `digitalocean`, `dnsimple`, `dnsmadeeasy`, `dnspod`, `dode`, `dreamhost`, `duckdns`, `dyn`, `dynu`, `easydns`, `edgedns`, `exec`, `exoscale`, `fastdns`, `gandi`, `gandiv5`, `gcloud`, `glesys`, `godaddy`, `hetzner`, `hostingde`, `httpreq`, `iij`, `internal`, `inwx`, `joker`, `lightsail`, `linode`, `linodev4`, `liquidweb`, `luadns`, `mydnsjp`, `mythicbeasts`, `namecheap`, `namedotcom`, `namesilo`, `netcup`, `netlify`, `nifcloud`, `ns1`, `oraclecloud`, `otc`, `ovh`, `pdns`, `rackspace`, `regru`, `rfc2136`, `rimuhosting`, `route53`, `sakuracloud`, `scaleway`, `selectel`, `servercow`, `stackpath`, `transip`, `vegadns`, `versio`, `vscale`, `vultr`, `yandex`, `zoneee`, `zonomi`
`LEGO_DNS_TIMEOUT` | `10` | Set the DNS timeout value to a specific value in seconds
`LEGO_ARGS` | _(none)_ | Send arguments directly to lego, e.g. `"--dns.disable-cp"` or `"--dns.resolvers 1.1.1.1"`
`<KEY/TOKEN_FROM_PROVIDER>` | _(none)_ | See [Configuration of DNS Providers](https://go-acme.github.io/lego/dns/)
`SET_ON_WEB` | true | Set the new certificate on the WebServer
`SET_ON_API` | true | Set the new certificate on the API
`SET_ON_OVPN` | false | Set the new certificate on the OpenVPN Server
`SET_ON_HOTSPOT` | false | Set the new certificate for the HotSpot/CaptivePortal
`HOTSPOT_PROFILE_NAME`| _(none)_ | HotSpot/CaptivePortal profile name

## SSH Setup

* Generate SSH Key Pair
* Upload Public key to RouterOS
* Add User/Group and import Public SSH Key
* Pass private key into Docker container

## Example

```yaml
version: "3"

services:
  app:
    image: foorschtbar/routeros-letsencrypt
    environment:
      - LEGO_STAGING=1 # 0 for production, 1 for staging (default)
      - LEGO_PROVIDER=digitalocean # Example
      - LEGO_DOMAINS=mydomain.tld # or *.mydomain.tld for a wildcard cert.
      - LEGO_EMAIL_ADDRESS=admin@mydomain.tld
      - DO_AUTH_TOKEN=changeme # Example
      - ROUTEROS_USER=letsencrypt
      - ROUTEROS_HOST=router.mydomain.tld
      - ROUTEROS_PRIVATE_KEY=/id-rsa
      - ROUTEROS_DOMAIN=mydomain.tld # or *.mydomain.tld for a wildcard cert.
    volumes:
      - ./data:/letsencrypt # To store persistent authorization information between container restarts
      - ./id-rsa:/id-rsa
    restart: unless-stopped
```

## Credits

Inspired by

* [acme-lego-cron](https://github.com/brahma-dev/acme-lego-cron)
* [Let's Encrypt RouterOS / Mikrotik](https://github.com/gitpel/letsencrypt-routeros)
