# Dashbase Quickstart

## Overview
Use this guide to start Dashbase locally and familiarize yourself with a few concepts. When done, you'll be ready to run a remote deployment and hook up your own data.

### Requirements

- [Docker Engine 17.06.0+](https://www.docker.com/community-edition#/download)
- Optionally [Docker Compose 1.17.0](https://docs.docker.com/compose/install)

### Start

1. Clone this git repo!

  `git clone https://github.com/dashbase/dashbase-quickstart.git`

2. Initialize a Docker Swarm

  `docker swarm init`

3. Run our prepare script to automatically download your license and configure SSL support for Dashbase.

  `./bin/prepare.sh { YOUR_DASHBASE.IO_EMAIL }`

4. Deploy the base stack locally.

  `docker stack deploy -c docker-compose.yml quickstart`
