DOCKER_REPO := hailstorm-web-client
PACKAGE_VERSION = $(shell cat package.json | jq -r '.version')

.PHONY:

clean:
	npm run clean

install:
	npm ci --no-progress

test:
	npm test -- --watchAll=false

coverage: .PHONY
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
	--label org.opencontainers.image.revision=$${TRAVIS_COMMIT}															\
	--label org.opencontainers.image.licenses=MIT																		\
	--label org.opencontainers.image.title="Hailstorm Web"																\
	-t $${DOCKER_ID}/${DOCKER_REPO}:${PACKAGE_VERSION} .

publish:
	set -ev
	@docker login --username $${DOCKER_ID} -p $${DOCKER_PASSWORD}
	docker tag $${DOCKER_ID}/${DOCKER_REPO}:${PACKAGE_VERSION} $${DOCKER_ID}/${DOCKER_REPO}:latest
	docker push $${DOCKER_ID}/${DOCKER_REPO}:${PACKAGE_VERSION}
	docker push $${DOCKER_ID}/${DOCKER_REPO}:latest


docker_image_id:
	@echo $${DOCKER_ID} ${DOCKER_REPO} ${PACKAGE_VERSION}

dev_run:
	BROWSER=none PORT=8080 npm start

validate:
	if ${TRAVIS_BUILD_DIR}/.travis/build-condition.sh ${TRAVIS_COMMIT_RANGE} hailstorm-web-client/src; then \
		git diff ${TRAVIS_COMMIT_RANGE} -- package.json | grep -e '[+\-].*version' > /dev/null; \
		[ $$? -eq 0 ]; \
	fi
