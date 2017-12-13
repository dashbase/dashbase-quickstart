# Dashbase Quickstart

## Overview
Use this guide locally to start Dashbase and familiarize yourself with a few concepts.

## Requirements

- [Docker Engine 17.06.0+](https://www.docker.com/community-edition#/download)
- Optionally [Docker Compose 1.17.0+](https://docs.docker.com/compose/install)
- At least 8GB of memory available to the Docker Engine (For macOS click the docker icon in the menu bar. Choose Preferences -> Advanced. Then move the slider of the memory setting to 8 GB or above)

### Instructions

```bash
# 1. Clone this git repo.
git clone https://github.com/dashbase/dashbase-quickstart.git

# 2. Initialize a Docker Swarm
docker swarm init

# 3. Run our prepare script to automatically download your license and configure SSL support for Dashbase.
./bin/prepare.sh {{ YOUR REGISTERED DASHBASE.IO EMAIL }}

# 4. Deploy the base stack locally.
docker stack deploy -c docker-compose.yml quickstart

# 5. Wait a few moments, then ensure all services are up and running.
docker service ls
```

Once all services are up, let's run a Filebeat locally to start putting in some data.

1. Get [Filebeat](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-installation.html) if you don't have it already.

2. Edit the `filebeat.yml` Elasticsearch output section, as such:
*Note that your license was retrieved as part of the ./bin/prepare.sh script you executed earlier

```
#-------------------------- Elasticsearch output ------------------------------
output.elasticsearch:
  # Array of hosts to connect to.

  hosts: ["localhost:9200"]

  protocol: https
  ssl.verification_mode: none

  username: ${DASHBASE_EMAIL}
  password: ${DASHBASE_LICENSE}
```

3. Start Filebeat and then visit our Dashbase [Web Interface](https://localhost:8080) to begin searching your logs!


