1. install minikube https://github.com/kubernetes/minikube

2. start minikube 
```

minikube start --cpus 4 --memory 8192

minikube ip
minikube dashboard

```





3. set license
```bash
vim k8s/10dashbase-config.yml
>> change dashbase-license to your license

``` 



4. start dashbase​

```
cd /path/to/project


kubectl create -f k8s/zookeeper
kubectl create -f k8s
kubectl create -f k8s/outside

# 
echo "dashbase-web:" `minikube ip`:32400
echo "dashbase-api:" `minikube ip`:32401
echo "dashbase-table:" `minikube ip`:32402

```

