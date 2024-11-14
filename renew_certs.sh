#!/bin/bash

sudo docker run --rm \
  -v /etc/letsencrypt:/etc/letsencrypt \
  -v $(pwd)/logs:/var/log/letsencrypt \
  -v $(pwd)/namecheap.ini:/namecheap.ini \
  my-certbot-dns-namecheap renew \
  -a dns-namecheap \
  --dns-namecheap-credentials /namecheap.ini \
  --quiet --no-self-upgrade

# previously:  $(pwd)/certs:/etc/letsencrypt 
# result:      $(pwd)/certs/live/domain.com
# desired:     /etc/letsencrypt/live/domain

# by changing /etc/letsencrypt:/etc/letsencrypt