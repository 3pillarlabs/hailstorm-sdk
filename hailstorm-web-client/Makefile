DOCKER_REPO := hailstorm-web-client
PACKAGE_VERSION = $(shell cat package.json | jq -r '.version')

clean:
	npm run clean

install:
	npm ci --no-progress

test:
	npm test -- --watchAll=false

coverage:
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -i; fi
	npm test -- --watchAll=false --coverage

cc_test_report:
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -u $(shell basename ${PWD}) -t lcov; fi

integration:
	cd e2e && \
	NODE_ENV=production npx wdio run wdio.smoke.conf.js

build:
	CI=false npm run build

package:
	find build -type f -exec cat {} + | sha1sum | cut -f1 -d' ' > BUILD_ID
	docker build \
	--rm \
	--label org.opencontainers.image.created=$(shell date -u "+%Y-%m-%dT%H:%M:%S%z")									\
	        org.opencontainers.image.revision=$${TRAVIS_COMMIT}															\
			org.opencontainers.image.licenses=MIT																		\
			org.opencontainers.image.title="Hailstorm Web"																\
	-t $${DOCKER_ID}/${DOCKER_REPO}:${PACKAGE_VERSION} .

publish:
	set -ev
	@docker login --username $${DOCKER_USERNAME} -p $${DOCKER_PERSONAL_ACCESS_TOKEN}
	docker tag $${DOCKER_ID}/${DOCKER_REPO}:${PACKAGE_VERSION} $${DOCKER_ID}/${DOCKER_REPO}:latest
	docker push $${DOCKER_ID}/${DOCKER_REPO}:${PACKAGE_VERSION}
	docker push $${DOCKER_ID}/${DOCKER_REPO}:latest


docker_image_id:
	@echo $${DOCKER_ID} ${DOCKER_REPO} ${PACKAGE_VERSION}
