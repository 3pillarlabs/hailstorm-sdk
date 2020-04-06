CLI_VERSION = $(shell ruby -I ./lib -r 'hailstorm/cli/version' -e 'puts Hailstorm::Cli::VERSION')
DOCKER_REPO := hailstorm-cli
IMAGE_DESC = $(shell ruby -e 'puts Gem::Specification.load("hailstorm-cli.gemspec").summary')
RELEASE_VERSION = $(shell grep VERSION lib/hailstorm/cli/version.rb | perl -ne "/\'([^\']+)\'/; print \$$1")

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
		mysql -e 'grant all privileges on *.* to "hailstorm_dev"@"localhost" identified by "hailstorm_dev";'; \
	fi

cc_test_report:
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -u $(shell basename ${PWD}) -t simplecov; fi

build:
	rake build

package:
	docker build 																										\
	--build-arg HAILSTORM_VERSION=$(shell ruby -I ./lib -r 'hailstorm/version' -e 'puts Hailstorm::VERSION') 			\
	--rm																												\
	--label org.opencontainers.image.created=$(shell date -u "+%Y-%m-%dT%H:%M:%S%z")									\
	--label org.opencontainers.image.revision=$${TRAVIS_COMMIT}															\
	--label	org.opencontainers.image.licenses=MIT																		\
	--label org.opencontainers.image.title="Hailstorm CLI"																\
	--label org.opencontainers.image.description="'${IMAGE_DESC}'"														\
	-t $${DOCKER_ID}/${DOCKER_REPO}:${CLI_VERSION} .

integration:
	docker run \
	-it \
	--rm \
	--network hailstorm-sdk_hailstorm_integration \
	-e DATABASE_HOST=hailstorm-db \
	-v $${PWD}/features:/usr/local/lib/hailstorm-cli/features \
	$${DOCKER_ID}/${DOCKER_REPO}:${CLI_VERSION} bash -c \
	'cd /usr/local/lib/hailstorm-cli && cucumber --tags @smoke features/console_app.feature'

publish:
	set -ev
	@docker login --username $${DOCKER_ID} -p $${DOCKER_PASSWORD}
	docker tag $${DOCKER_ID}/${DOCKER_REPO}:${CLI_VERSION} $${DOCKER_ID}/${DOCKER_REPO}:latest
	docker push $${DOCKER_ID}/${DOCKER_REPO}:${CLI_VERSION}
	docker push $${DOCKER_ID}/${DOCKER_REPO}:latest


open_console:
	docker run \
	-it \
	--rm \
	--network hailstorm-sdk_hailstorm \
	-e DATABASE_HOST=hailstorm-db \
	-v $${PWD}:/hailstorm \
	$${DOCKER_ID}/${DOCKER_REPO}:${CLI_VERSION} dockerize -wait tcp://hailstorm-db:3306 bash


open_test_console:
	docker run \
	-it \
	--rm \
	--network hailstorm-sdk_hailstorm_integration \
	-e DATABASE_HOST=hailstorm-db \
	$${DOCKER_ID}/${DOCKER_REPO}:${CLI_VERSION} bash


docker_image_id:
	@echo $${DOCKER_ID} ${DOCKER_REPO} ${CLI_VERSION}


release_makefile:
	@./release-makefile.sh ${DOCKER_REPO} ${RELEASE_VERSION}
