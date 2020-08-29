DOCKER_REPO := hailstorm-api
PACKAGE_VERSION = $(shell ruby -I ./app -r 'version' -e 'puts Hailstorm::Api::VERSION')
API_PORT := 4567
TIMEOUT = 300

install:
	bundle install

test: create_mysql_user
	JRUBY_OPTS="--debug" bundle exec rspec -f Croaky::RSpec::CroakyFormatter

coverage: create_mysql_user
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -i; fi
	HAILSTORM_COVERAGE="true" JRUBY_OPTS="--debug" bundle exec rspec -f Croaky::RSpec::CroakyFormatter

create_mysql_user:
	if [ -n "${CI}" ]; \
	then \
		mysql -e 'grant all privileges on *.* to "hailstorm"@"localhost" identified by "hailstorm";'; \
	fi

cc_test_report:
	if [ -n "${CI}" ]; then ${TRAVIS_BUILD_DIR}/.travis/coverage.sh -u $(shell basename ${PWD}) -t simplecov; fi

package:
	bundle package && \
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

dev_run:
	bundle exec rackup -p ${API_PORT}

listen_port:
	@ok=0; \
	elapsed=0; \
	while [ $$elapsed -lt $(TIMEOUT) ] && [ $$ok -eq 0 ]; do \
	  curl -s http://localhost:${API_PORT}/ && ok=1; \
	  if [ $$elapsed -lt $(TIMEOUT) ] && [ $$ok -eq 0 ]; then \
	    sleep 10; \
		elapsed=$$(expr $$elapsed + 10); \
	  fi; \
	done; \
	[ $$ok -eq 1 ]

validate:
	API_VERSION_CHANGED=0; \
	for glob in app config *.rb config.ru Gemfile.lock; do \
		if ${TRAVIS_BUILD_DIR}/.travis/build-condition.sh ${TRAVIS_COMMIT_RANGE} hailstorm-api/$$glob; then \
			${TRAVIS_BUILD_DIR}/.travis/build-condition.sh ${TRAVIS_COMMIT_RANGE} hailstorm-api/app/version.rb; \
			API_VERSION_CHANGED=$$?; \
			break; \
		fi; \
	done; \
	[ $$API_VERSION_CHANGED -eq 0 ]
