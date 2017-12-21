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

4. Deploy the core stack first. This stack includes Dashbase Web, API service, and all internal metrics & monitoring as well as Kafka and ZooKeepers.
```
docker stack deploy -c docker-stack-core.yml dashbase-core
```
*Note: At this point Dashbase is running and you can find the UI on the default port: 8080 of the machine. (On a Mac, it's localhost:8080, and you'll have to click past the security warnings.) You'll be able to click on Cluster Overview and see multiple internal tables (their names prepended with an underscore) that are collecting system metrics.

5. Create a table in the Dashbase with 1 partition, 1 replica, and smaller heap size for testing. This command outputs a docker-stack-quickstart.yml that we will use to deploy our table stack.

```
docker pull dashbase/create_table
docker run -v $PWD:/output dashbase/create_table quickstart -p 1 -r 1 --heap-opts "-Xmx4g -Xms2g -XX:NewSize=2g"
```

6. Deploy the table stack
```
docker stack deploy -c docker-stack-quickstart.yml quickstart
```

7. Wait a few moments, then ensure all services are up and running.
```
docker service ls
```

Expected output should be similar to below with all REPLICAS as x/x (except `dashbase-core_grafana_restart_dashbase_app` which is expected to stay as 0/1):
```
ID                  NAME                                         MODE                REPLICAS            IMAGE                                      PORTS
qtd2ph6mj87a        dashbase-core_api                            replicated          1/1                 dashbase/api:latest                       *:9876->9876/tcp
...
```

*Note: On the same Cluster Overview UI noted above, you will now see the new table that you just created, ingesting no data.

Once all services are up, let's run a Filebeat locally to start putting in some data.

1. [Get Filebeat](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-installation.html) if you don't have it already.

2. Edit the `filebeat.yml` Elasticsearch output section, as such:

*Note that your license was retrieved as part of the ./bin/prepare.sh script you executed earlier.

```
#-------------------------- Elasticsearch output ------------------------------

setup.template.name: quickstart
setup.template.pattern: quickstart
output.elasticsearch:
  # Array of hosts to connect to.

  hosts: ["localhost:9200"]

  index: "quickstart"

  protocol: https
  ssl.verification_mode: none

  username: ${DASHBASE_EMAIL}
  password: ${DASHBASE_LICENSE}
```

3. [Start Filebeat](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-starting.html) and then visit our Dashbase [Web Interface](https://localhost:8080) to begin searching your logs!

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

To create a swarm on new EC2 instance(s), in a new VPC, Docker provides [a CloudFormation template just for you](https://console.aws.amazon.com/cloudformation/home#/stacks/new?stackName=Docker&templateURL=https://editions-us-east-1.s3.amazonaws.com/aws/stable/Docker.tmpl). 

Docker provides a variety of [other CloudFormation templates](https://docs.docker.com/docker-for-aws/#quickstart) that allow you to bring an existing VPC, or use a newer version of Docker. We recommend using the stable build.

Depending on the desired number of Dashbase partitions and replicas per, please add enough worker nodes for each partition or replica to have its own instance. Add an additional worker to your total count for the Dashbase core stack.

Configuration for reference:
In this example, we will only run a single Dashbase partition with a replication factor of 1. Therefore we only need 1 worker instance for the table partition, but we add one for the core stack.
![Docker on AWS configurations](https://i.gyazo.com/252bfedff5c571b61ad2ce2d4f1fb1c1.png "Docker on AWS")

If you already have an EC2 instance on AWS that you want to deploy Dashbase onto, then please ssh to the instance and run:
```
docker swarm init
```

**IMPORTANT** the CloudFormation template automatically creates instances with a spread across all available AZs. This could incure Amazon's data-transfer charges. Depending on requirements, you can configure the Auto Scale Group created by the CloudFormation to only create instances in a specific AZ and terminate instances that are not within that AZ. If redundancy or cross-AZ fault tolerance is necessary, then please consult with [on-demand Amazon pricing](https://aws.amazon.com/ec2/pricing/on-demand/) to calculate the cost for data-transfer.

2. Clone this repository to your local machine.
```
git clone https://github.com/dashbase/dashbase-quickstart.git
```

3. Run our prepare script to automatically download your license and configure SSL support for Dashbase.

*Note that you will need your AWS credentials set before running this step.
This can be done via using the AWS CLI or exporting the env variables.
Reference: http://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/setup-credentials.html
This is only necessary because the REX-ray Docker volume plugin requires an IAM user with the EBS permissions.
For inquiries, please reference their documentation.
```
./bin/prepare.sh {{ YOUR REGISTERED DASHBASE.IO EMAIL }}
# Answer `y` for all prompts if any.
```

4. Create a table with 1 partition, 1 replica, and an automatically attached EBS volume. We will use defaults for all other settings.
```
docker pull dashbase/create_table
docker run -v $PWD:/output dashbase/create_table quickstart -p 1 -r 1 --ebs-volume 1500
```

*Note that this command outputs a yaml file that describes the table stack, with each service mapping directly to a Dashbase partition. The stack is not automatically deployed, but we will do so in the next steps. Since the script uses a Docker image, if SSH tunneling is set up, it may result in the output being produced to the remote instance. The EBS volume(s) are also automatically created by the REX-ray Docker plugin, with a recommended size of 1500 GiB due to the fact that Amazon throttles throughput for HDDs (st1) type which could affect Dashbase's performance.

5. Configure your local Docker to use the remote Docker daemon running on the swarm cluster manager.

```
ssh -i {{ PATH/TO/SSH/KEY }} -o StrictHostKeyChecking=no -fNL localhost:2374:/var/run/docker.sock docker@{{ MANAGER NODE IP ADDRESS }}
export DOCKER_HOST=localhost:2374
```
More info can be found in [Docker docs](https://docs.docker.com/docker-for-aws/deploy/#manager-nodes).

6. Install the REX-ray volume plugin onto the swarm cluster. This command only needs to be ran once if completed with swarm-exec as Docker will automatically re-run on new nodes that join the cluster.
```
# If you used Docker for AWS
ssh -i {{ PATH/TO/SSH/KEY }} -o StrictHostKeyChecking=no docker@{{ Manager node's IP address }} swarm-exec $(cat rexray_cmd)

# If you are using existing EC2 instances, please run this command for every worker node
ssh -i {{ PATH/TO/SSH/KEY }} {{ EC2 INSTANCE }} "$(cat rexray_cmd)"
```

If you are using an existing EC2 instance, you can set up SSH tunneling to the Docker daemon running on the manager instance (see the above example), or you can SCP the contents of the current directory to the host instance and run the next step from there. Make sure that the instance has `docker-compose` installed.

7. Choose a worker node to be the designated core stack node.
```
# list all nodes in the swarm
docker node ls

# add a label to one of the worker nodes. (Choose a node that does not say "Leader")
docker node update --label-add core=true {{ NODE ID }}

# get and save the IP address of the instance for accessing Dashbase Web UI
docker node inspect {{ NODE ID }} | grep Hostname

# take the hostname and go to AWS Console to get the public IP of the host instance if necessary.
# it is useful to edit the name of the ec2 instance in the AWS console to mark that this is the swarm worker running Dashbase's core deployment components (everything that is not a worker dedicated to a partition).
```

*Note that you can label worker nodes with the specific table name that it should run, e.g. `docker node update --label-add name=quickstart {{ NODE ID }}` to help Docker Swarm speed up the process of allocating the table's partitions (stack services). However, nodes should not have conflicting labels, such as the worker nodes being labled with `core=true`, as that could cause Docker to run the Dashbase core services on instances that should only be dedicated to Dashbase partitions/replicas.

8. Compile the core stack yaml with `docker-compose`and deploy it.
```
docker-compose -f docker-stack-core.yml -f docker-stack-core-aws.yml config | docker stack deploy -c - dashbase-core
```

9. Deploy the table stack you generated earlier.
```
docker stack deploy -c docker-stack-quickstart.yml quickstart
```

10. Wait a few moments, then ensure all services are up and running.
```
docker service ls
```

Expected output should be similar to below with all REPLICAS as x/x (except `dashbase-core_grafana_restart_dashbase_app` which is expected to stay as 0/1):
```
ID                  NAME                                         MODE                REPLICAS            IMAGE                                      PORTS
qtd2ph6mj87a        dashbase-core_api                            replicated          1/1                 dashbase/api:latest                       *:9876->9876/tcp
...
```

### How to access

If you created a swarm cluster using Docker for AWS, then it set up an ELB for access to the cluster. The DNS of the ELB is available in the `DefaultDNSTarget` under `Outputs` tab on the CloudFormation page.

If you deployed to the existing EC2 instance (without using Docker for AWS), then you can use the public IP/hostname of the instance running the core stack to access the web.

You can access to Dashbase Web page via https://{{ ELB DNS OR PUBLIC IP/HOSTNAME OF CORE }}:8080/.


# Scaling

How-to for scaling Dashbase and Kafka.

### Increase Kafka Topic Partitions

1. SSH into the dashbase-core host machine that has the dashbase-core_kafka service.

2. Get the container and SSH into the container.
```
docker ps | grep dashbase-core_kafka
docker exec -it <CONTAINER_ID> sh
```
3. Run the topics alter script command to increase number of partitions.
```
./opt/kafka_2.12-0.11.0.1/bin/kafka-topics.sh --zookeeper zookeeper:2181 --topic {{ TOPIC }} --alter --partitions {{ NUMBER OF PARTITIONS }}
```

# Shutting Down

Procedure for shutdown and cleanup.

### Shutting down a stack
1. Get the list of stacks.
```
docker stack ls
```

2. Remove desired stack using name reference. *Note that this does not remove the EBS volumes created by REX-ray nor the Docker volumes for logs. View the next section to do so.
```
docker stack rm {{ STACK NAME }}
# Rerun this command as necessary until output displays:
Nothing found in stack: {{ STACK NAME }}
```
Stack dependencies, e.g. `networks` or `secrets` may not be removed if other stacks are using them. Other errors during stack remove can be ignored.


### Cleaning up volumes after shutting down a stack; this will remove all persistent data
1. Remove REX-ray created EBS volumes by going to the AWS Web Console -> `EC2` -> `Volumes` on the left-hand column -> Select and remove all volumes tagged with REX-ray in `State: Available` filter.

2. SSH to each worker node and run Docker's volume prune command
```
ssh -i {{ PATH/TO/SSH/KEY }} docker@{{ EC2 INSTANCE IP }}
docker volume prune
```
Expected output:
```
Welcome to Docker!
~ $ docker volume prune
WARNING! This will remove all volumes not used by at least one container.
Are you sure you want to continue? [y/N] y
Deleted Volumes:
...
Total reclaimed space: X
```

### Cleaning up an instance completely
1. SSH to the instance.
```
ssh -i {{ PATH/TO/SSH/KEY }} docker@{{ EC2 INSTANCE IP }}
```

2. Run Docker provided prune commands to remove all stopped containers and unused volumes.
```
docker system prune
docker volume prune
```

# Troubleshooting

Tips on how to troubleshoot various encountered problems.

### Core or table(s) services show 0/1 or x/y replicas

1. Run service ps with no truncate to see if the Docker service failed to initialize due to a Docker or AWS related issue.
```
docker service ps {{ SERVICE NAME }} --no-trunc
```
This will output information on the state of the service, or any errors during the service initiation process. Address the issues and redeploy the stack.
```
docker stack deploy -c {{ STACK YAML }} {{ STACK NAME }}
```

2. If there are no results or the error is `task: non-zero exit (1)` or if the status is ready, check the logs for any obvious errors or exceptions:
```
docker service logs {{ SERVICE NAME }}
```
This will output the latest snippet of stdout and stderr of the internal service by default. If the output is blank, please revisit the first step as the service did not start. Check the [Docker](https://docs.docker.com/engine/reference/commandline/service_logs/#options) documentation for additional options.

3. Manually get the logs (usually not necessary); requires SSH to the host instance the service is running on:
```
# If you have trouble finding the IP address of the instance the service is running on, you can get the node hostname the service is running on using the following step, then filter with the AWS EC2 Web Console for the actual instance.
docker service ps {{ SERVICE NAME }}

# SSH to the remote host instance.
ssh -i {{ PATH/TO/SSH/KEY }} docker@{{ EC2 INSTANCE IP }}

# Run docker ps to get the container ID then ssh into the container.
docker ps | grep {{ SERVICE NAME }}
docker exec -it {{ CONTAINER ID }} sh

# Check the logs in /app/logs for Dashbase services
cd /app/logs/
less ...
```


