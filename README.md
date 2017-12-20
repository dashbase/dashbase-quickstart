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

5. Create a table in the Dashbase with 1 partition, 1 replica, and smaller heap size for testing. This command outputs a docker-stack-quickstart.yml that we will use to deploy our table stack. You will need to be logged in to docker via ```docker login```.

```
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

Expected output should be similar to below with all REPLICAS as x/x:
```
ID                  NAME                                         MODE                REPLICAS            IMAGE                                      PORTS
qtd2ph6mj87a        dashbase-core_api                            replicated          1/1                 dashbase/api:latest                       *:9876->9876/tcp
...
```

Once all services are up, let's run a Filebeat locally to start putting in some data.

1. [Get Filebeat](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-installation.html) if you don't have it already.

2. Edit the `filebeat.yml` Elasticsearch output section, as such:

*Note that your license was retrieved as part of the ./bin/prepare.sh script you executed earlier.

```
#-------------------------- Elasticsearch output ------------------------------

setup.template.name: "quickstart"
setup.template.pattern: "quickstart"
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

If you want to create a new EC2 instance on AWS, you can use the CloudFormation template(s) provided [by Docker](https://docs.docker.com/docker-for-aws/#quickstart) to set up a Swarm cluster on AWS.

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
docker run -v $PWD:/output dashbase/create_table quickstart -p 1 -r 1 --ebs-volume 1500
```

*Note that this command outputs a yaml file that describes the table stack, with each service mapping directly to a Dashbase partition. The stack is not automatically deployed, but we will do so in the next steps. Since the script uses a Docker image, if SSH tunneling is set up, it may result in the output being produced to the remote instance. The EBS volume(s) are also automatically created by the REX-ray Docker plugin, with a recommended size of 1500 GiB due to the fact that Amazon throttles throughput for HDDs (st1) type which could affect Dashbase's performance. 

5. Configure your local Docker to use the remote Docker daemon running on the swarm cluster manager.

If you used Docker for AWS, please follow [these instructions](https://docs.docker.com/docker-for-aws/deploy/#manager-nodes) to set up SSH tunneling and set the DOCKER_HOST environmental variable. Here is the example from the instructions:
```
ssh -i {{ PATH/TO/SSH/KEY }} -o StrictHostKeyChecking=no -fNL localhost:2374:/var/run/docker.sock docker@{{ MANAGER NODE IP ADDRESS }}
export DOCKER_HOST=localhost:2374
```

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
docker node ls
docker node update --label-add core=true {{ NODE ID }}
# get and save the IP address of the instance for accessing Dashbase Web UI
docker node inspect {{ NODE ID }} | grep Hostname
# take the hostname and go to AWS Console to get the public IP of the host instance if necessary.
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

Expected output should be similar to below with all REPLICAS as x/x:
```
ID                  NAME                                         MODE                REPLICAS            IMAGE                                      PORTS
qtd2ph6mj87a        dashbase-core_api                            replicated          1/1                 dashbase/api:latest                       *:9876->9876/tcp
...
```

### How to access

If you created a swarm cluster using Docker for AWS, then it set up an ELB for access to the cluster. The DNS of the ELB is available in the `DefaultDNSTarget` under `Outputs` tab on the CloudFormation page.

If you deployed to the existing EC2 instance (without using Docker for AWS), then you can use the public IP/hostname of the instance running the core stack to access the web.

You can access to Dashbase Web page via https://{{ ELB DNS OR PUBLIC IP/HOSTNAME OF CORE }}:8080/.
