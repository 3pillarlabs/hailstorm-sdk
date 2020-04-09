# Hailstorm File Server

``hailstorm-file-server`` is a generic file server, that is used in the Hailstorm application suite to upload and
serve project files. The file server stores the files in a directory hierarchy under a configurable root/base path.

# Quick Start

Run it from the command line without any arguments. This will upload to and serve files from ``/hailstorm`` path on the
local file system.
```bash
./gradlew bootRun
```

If you want to upload and serve from a different path, use the ``basePath`` argument to specify a different
path on the local file system.

```bash
./gradlew bootRun --args=--basePath=/tmp/hailstorm/dev
```

# Docker

- Map the ``/hailstorm`` path in the container to ``/tmp/hailstorm/dev`` on local file system.
- Map local port `9000` to port `8080` on the container.

```bash
make package

docker run \
-it \
--rm \
--name=hailstorm-fs \
--volume "/tmp/hailstorm/dev:/hailstorm" \
-p "9000:8080" \
hailstorm/hailstorm-file-server
```
