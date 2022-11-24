# Dynamic hostports **with Node FQDN** for Kubernetes

This tool will let you deploy pods with a dynamic hostport.
Sortof a polyfill for https://github.com/kubernetes/kubernetes/issues/49792

## **Node FQDN**

This project is a simple fork of the [original one](https://github.com/0blu/dynamic-hostports-k8s). It does everything the original does, plus sinjects the fully qualified domain name of the node that the pod was assigned to as a label to the pod.

You can combine this feature with the original hostport feature to be able to know the "externally" accessible domain from within the pod. Here is an example exposing an SSH server from within the pod:

### Example

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: dind
  labels:
    dynamic-hostports: "22"
spec:
  containers:
    - name: dind
      image: ghcr.io/felipecrs/jenkins-agent-dind:latest
      imagePullPolicy: Always
      env:
        - name: SSHD_ENABLED
          value: "true"
      ports:
        - containerPort: 22
      securityContext:
        privileged: true
      args:
        - sleep
        - infinity
      volumeMounts:
        - name: podinfo
          mountPath: /ssh-command/podinfo
  volumes:
    - name: podinfo
      downwardAPI:
        items:
          - path: "sshd-port"
            fieldRef:
              fieldPath: metadata.annotations['dynamic-hostports.k8s/22']
          - path: "node-fqdn"
            fieldRef:
              fieldPath: metadata.annotations['dynamic-hostports.k8s/node-fqdn']
```

And you can obtain the SSH command by running:

```bash
kubectl exec dind -- bash -c 'echo "ssh ssh://$(whoami)@$(cat /ssh-command/podinfo/node-fqdn):$(cat /ssh-command/podinfo/sshd-port)"'
```

The output should be something like:

```bash
ssh ssh://user@my-node-x.domain:13245
```

If the node itself does not have a fully qualified domain, this tool won't do any magic. The content of the label attached by the tool will be the same of the output of running the command `hostname -f` in the node. That's even how it works.

It's very useful for example in an internal company network, which you can access any VM by using their FQDN.

### Credits

All credits goes to @0blu for the original project. The documentation below is just a "copy" of the original one, with the proper changes applied.

## How it works

If a new pod is being detected this tool will automatically create a nodeport service and an endpoint to this pod/port.  
The service will be created within the namespace of the pod and is also limited to the external ip of the node.

# Install

Cluster wide
``` bash
kubectl apply -f https://raw.githubusercontent.com/felipecrs/dynamic-hostports-k8s/master/deploy.yaml
```

If you want, you can also modify this file and use the `KUBERNETES_NAMESPACE` environment variable to limit the access.

> **Node FQDN note:** You can also modify this file and change the `FQDN_IMAGE` (default to `busybox:latest`) to something else, which may be useful when you need to use an internal mirror for Docker Hub.

You can also build it yourself:

``` bash
docker build -t ghcr.io/felipecrs/dynamic-hostport-manager:latest .
```

Hosted on GitHub Container Registry: https://ghcr.io/felipecrs/felipecrs/dynamic-hostport-manager

# Example

This example will create 5 pods; each having 2 public servers with different outgoing (host)ports.

``` yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dynamic-hostport-example
spec:
  replicas: 5
  selector:
    matchLabels:
      app: dynamic-hostport-example-deployment
  template:
    metadata:
      annotations:
        # dynamic-hostports.k8s/8080: 'DO NOT SET' # This value will be automatically set by the tool
        # dynamic-hostports.k8s/8082: 'DO NOT SET' # you can query it to determine the outgoing hostport
        # dynamic-hostports.k8s/node-fqdn: 'DO NOT SET' # you can query it to determine the fully qualified hostname of the node running the pod
      labels:
        app: dynamic-hostport-example-deployment
        # This is where the magic happens
        dynamic-hostports: '8080.8082' # Must be a string. Split multiple ports with '.'
    spec:
      containers:
      - name: dynamic-hostport-example1-container
        image: paulbouwer/hello-kubernetes:1.8
        env:
          - name: MESSAGE
            value: Hello from port 8080
          # - name: PORT
          #   value: '8080' # 8080 Is standard port of paulbouwer/hello-kubernete
        ports:
        - containerPort: 8080
          # hostPort: DO NOT SET THIS HERE
      - name: dynamic-hostport-example2-container
        image: paulbouwer/hello-kubernetes:1.8
        env:
          - name: MESSAGE
            value: Hello from port 8082
          - name: PORT
            value: '8082'
        ports:
        - containerPort: 8082
          # hostPort: DO NOT SET THIS HERE
```

## Get the port and ip

You can get the dynamically assigned hostport by querying for 'dynamic-hostports.k8s/YOURPORT' annotation

``` bash
$ kubectl get pods -l dynamic-hostports --template '{{range .items}}{{.metadata.name}}  PortA: {{index .metadata.annotations "dynamic-hostports.k8s/8080"}}  PortB: {{index .metadata.annotations "dynamic-hostports.k8s/8082"}}  Node FQDN: {{index .metadata.annotations "dynamic-hostports.k8s/node-fqdn"}}{{"\n"}}{{end}}'
dynamic-hostport-example-f9bf6855c-78gzd  PortA: 30535  PortB: 31011  Node FQDN: my-node-1.domain
dynamic-hostport-example-f9bf6855c-89zxj  PortA: 32373  PortB: 30857  Node FQDN: my-node-2.domain
dynamic-hostport-example-f9bf6855c-8qtfd  PortA: 31755  PortB: 31584  Node FQDN: my-node-1.domain
dynamic-hostport-example-f9bf6855c-gwc9s  PortA: 30378  PortB: 31472  Node FQDN: my-node-1.domain
dynamic-hostport-example-f9bf6855c-st7ck  PortA: 31341  PortB: 30239  Node FQDN: my-node-2.domain
```

## Test it

This examples shows how to use this for _PortA_ on the _first_ pod

``` bash
$ curl http://my-node-x.domain:30535
```

This examples shows how to use this for _PortB_ on the _second_ pod

``` bash
$ curl http://my-node-y.domain:30857
```
