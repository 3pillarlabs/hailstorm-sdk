DOCKER_REPO := hailstorm-api
PACKAGE_VERSION = $(shell ruby -I ./app -r 'version' -e 'puts Hailstorm::Api::VERSION')

install:
	bundle install

test: create_mysql_user
	JRUBY_OPTS="--debug" rspec -f HailstormCiFormatter

coverage: create_mysql_user
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -i; fi
	HAILSTORM_COVERAGE="true" JRUBY_OPTS="--debug" rspec -f HailstormCiFormatter

create_mysql_user:
	if [ -n "${CI}" ]; \
	then \
		mysql -e 'grant all privileges on *.* to "hailstorm"@"localhost" identified by "hailstorm";'; \
	fi

cc_test_report:
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -u $(shell basename ${PWD}) -t simplecov; fi

package:
	docker build \
	--rm \
	--label org.opencontainers.image.created="$(shell date -u "+%Y-%m-%dT%H:%M:%S%z")"									\
	--label org.opencontainers.image.revision=$${TRAVIS_COMMIT}															\
	--label org.opencontainers.image.licenses=MIT																		\
	--label org.opencontainers.image.title="Hailstorm API"																\
	-t $${DOCKER_ID}/${DOCKER_REPO}:${PACKAGE_VERSION} .

publish:
	set -ev
	@docker login --username $${DOCKER_ID} -p $${DOCKER_PASSWORD}
	docker tag $${DOCKER_ID}/${DOCKER_REPO}:${PACKAGE_VERSION} $${DOCKER_ID}/${DOCKER_REPO}:latest
	docker push $${DOCKER_ID}/${DOCKER_REPO}:${PACKAGE_VERSION}
	docker push $${DOCKER_ID}/${DOCKER_REPO}:latest


docker_image_id:
	@echo $${DOCKER_ID} ${DOCKER_REPO} ${PACKAGE_VERSION}
