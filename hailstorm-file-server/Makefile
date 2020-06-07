DOCKER_REPO := hailstorm-file-server
PACKAGE_VERSION = $(shell grep -e '^version' build.gradle | cut -f2 -d'=' | sed s/\'/\"/g | perl -ne '/^\s*"(.+)"$$/; print $$1')

clean:
	./gradlew clean

install:
	./gradlew clean assemble

test:
	./gradlew test

coverage:
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -i; fi
	./gradlew test jacocoTestReport

cc_test_report:
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -u $(shell basename ${PWD}) -t jacoco; fi

package:
	./gradlew clean build docker

publish:
	set -ev
	@docker login --username $${DOCKER_ID} -p $${DOCKER_PASSWORD}
	docker tag $${DOCKER_ID}/${DOCKER_REPO}:${PACKAGE_VERSION} $${DOCKER_ID}/${DOCKER_REPO}:latest
	docker push $${DOCKER_ID}/${DOCKER_REPO}:${PACKAGE_VERSION}
	docker push $${DOCKER_ID}/${DOCKER_REPO}:latest

docker_image_id:
	@echo $${DOCKER_ID} ${DOCKER_REPO} ${PACKAGE_VERSION}

dev_run:
	./gradlew bootRun --args='--basePath=/tmp/hailstorm/dev/fs --server.port=9000'

validate:
	if ${TRAVIS_BUILD_DIR}/.travis/build-condition.sh ${TRAVIS_COMMIT_RANGE} hailstorm-file-server/src/main; then \
		git diff ${TRAVIS_COMMIT_RANGE} -- build.gradle | grep -e '[+\-]version' > /dev/null; \
		[ $$? -eq 0 ]; \
	fi
