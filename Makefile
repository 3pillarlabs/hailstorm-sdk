all: file_server web_client

.PHONY: all

file_server:
	cd hailstorm-file-server && \
	./gradlew clean bootJar docker

web_client:
	cd hailstorm-web-client && npm run package
