#!/usr/bin/python

# Docker swarm registers IP addresses of replicated service with DNS hostname
# 'tasks.{service_name}'. This scripts looks up the IP addressess of a given
# HOSTS and wait until # of the returned IP addresses matches NUM_REPLICAS,
# and then start metricbeat to collect metrics from those IP addresses.

from subprocess import call
import os
import socket
import sys
import time

hosts = os.environ['HOSTS']

ips = []

while len(ips) < int(os.environ['NUM_REPRICAS']):
    sys.stderr.write("not enough replicas found. will wait for a while and try again.\n")
    time.sleep(10)
    ips = socket.gethostbyname_ex(hosts)[2]
    sys.stderr.write("IP addresses for {}: {}\n".format(hosts, ips))


tables = ",".join([ ip + ":7988" for ip in ips])

call(['metricbeat', '-e', '-E', 'metricbeat.modules.0.hosts={}'.format(tables)])
