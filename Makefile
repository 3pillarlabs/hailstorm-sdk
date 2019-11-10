.PHONY: ALL

ALL: file_server web_client
	echo "All Done!"

web_client:
	cd hailstorm-file-server && \
	./gradlew clean bootJar docker

file_server:
	cd hailstorm-web-client && npm run package
