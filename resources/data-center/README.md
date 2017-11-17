## Build an image

```bash
docker build -t hailstorm-data-center-node:latest .
```

## Run the container

```bash
docker run -it --rm --name hs-dc-node-1 hailstorm-data-center-node:latest
```

### and daemonize

```bash
docker run -it --rm --name hs-dc-node-1 -d hailstorm-data-center-node:latest
```

### port mapping SSH

```bash
docker run -it --rm --name hs-dc-node-1 -d -p8022:22 hailstorm-data-center-node:latest
```

