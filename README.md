# Deploy Dashbase locally (onto your laptop or dev machine)

Use this guide to start Dashbase locally and familiarize yourself with a few concepts.

### Requirements

- [Docker Engine 17.06.0+](https://www.docker.com/community-edition#/download)
- Optionally [Docker Compose 1.17.0+](https://docs.docker.com/compose/install)
- At least 10GB of memory available to the Docker Engine (For macOS, click the Docker icon in the menu bar. Choose Preferences -> Advanced. Then move the slider of the memory setting to 10 GB or above)

### Instructions

1. Clone this git repo.
```
git clone https://github.com/dashbase/dashbase-quickstart.git
```

2. Initialize a Docker Swarm (Note: if you have done this before, you don't need to run this again.)
```
docker swarm init
```

3. Run our prepare script to automatically download your license and configure SSL support for Dashbase.
```
# Execute the following from the dashbase-quickstart directory
./bin/prepare.sh {{ YOUR REGISTERED DASHBASE.IO EMAIL }}
# Answer `y` for all prompts if any. Ignore requirement of AWS credentials.
```

4. Deploy the base stack locally.
```
docker stack deploy -c docker-compose.yml quickstart
```

5. Wait a few moments, then ensure all services are up and running.
```
docker service ls
```

Once all services are up, let's run a Filebeat locally to start putting in some data.

1. Get [Filebeat](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-installation.html) if you don't have it already.

2. Edit the `filebeat.yml` Elasticsearch output section, as such:

*Note that your license was retrieved as part of the ./bin/prepare.sh script you executed earlier.

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

--------
# Deploy Dashbase onto AWS

Use this guide to start Dashbase on AWS.

### Requirements

You need to install the following applications on your local machine.

- [Docker Engine 17.06.0+](https://www.docker.com/community-edition#/download) installed on each host if you already have machines provisioned.
- [Docker Compose 1.17.0+](https://docs.docker.com/compose/install/) installed on local machine.
- Optionally [AWS CLI](http://docs.aws.amazon.com/cli/latest/userguide/installing.html)

### Instructions

This section has reference to Docker swarm mode [node](https://docs.docker.com/engine/swarm/key-concepts/#nodes) concepts. If you are unfamiliar, please visit the link and read Docker's description.

1. Create a swarm cluster on AWS

If you want to create a new EC2 instance on AWS, you can use the CloudFormation template provided [by Docker](https://docs.docker.com/docker-for-aws/#deployment-options) to set up a Swarm cluster on AWS.

Configuration:

![Docker on AWS configurations](https://user-images.githubusercontent.com/847884/33967146-14c2a4da-e017-11e7-9625-d36303096df4.png "Docker on AWS")

If you already have an EC2 instance on AWS that you want to deploy Dashbase onto, then please ssh to the instance and run

```
docker swarm init
```

2. Clone this repository to your local machine.
```
git clone https://github.com/dashbase/dashbase-quickstart.git
```

3. Run our prepare script to automatically download your license and configure SSL support for Dashbase.

*Note that you will need your AWS credentials set before running the next step.
This can be done via using the AWS CLI or exporting the env variables.
Reference: http://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/setup-credentials.html
This is only necessary because the REX-ray Docker volume plugin requires an IAM user with the EBS permissions.
For inquiries, please reference their documentation.
```
./bin/prepare.sh {{ YOUR REGISTERED DASHBASE.IO EMAIL }}
# Answer `y` for all prompts if any.
```

4. Install Rexray volume plugin onto the swarm cluster.
```
# If you used Docker for AWS
ssh -i {{ PATH/TO/SSH/KEY }} -o StrictHostKeyChecking=no docker@{{ Manager node's IP address }} swarm-exec $(cat rexray_cmd)

# If you are using the existing EC2 instance
ssh -i {{ PATH/TO/SSH/KEY }} {{ EC2 instance }} "$(cat rexray_cmd)"
```

5. Configure your docker to use the remote docker daemon running on the swarm cluster

If you use Docker for AWS, please follow [this instruction](https://docs.docker.com/docker-for-aws/deploy/#manager-nodes) to set SSH tunnel and set DOCKER_HOST environmental variable. Here is the example from the instruction.
```
ssh -i {{ PATH/TO/SSH/KEY }} -o StrictHostKeyChecking=no -fNL localhost:2374:/var/run/docker.sock docker@{{ Manager node's IP address }}
export DOCKER_HOST=localhost:2374
```

If you are using an existing EC2 instance, you can set up SSH tunnel to the Docker daemon running on the instance (see the above example), or you can SCP the contents of the current directory to the instance, and run the next step on the instance. Make sure that the instance have docker-compose installed.

6. Deploy the stack.
```
docker-compose -f docker-compose.yml -f docker-compose-rexray-ebs.yml config | docker stack deploy -c - {{ YOUR STACK NAME }}
```

7. Wait a few moments, then ensure all services are up and running.
```
docker service ls
```

### How to access

If you created a swarm cluster using Docker for AWS, then it set up ELB to access to the cluster. The DNS of the ELB is available in the `DefaultDNSTarget` under `Outputs` tab on the CloudFormation page.

If you deployed to the existing EC2 instance (without using Docker for AWS), then you can use the public IP/hostname of the instance.

You can access to Dashbase Web page via https://{{ ELB DNS, or public IP/hostname }}:8080/.
