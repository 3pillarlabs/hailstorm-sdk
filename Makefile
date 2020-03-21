CHANGES = ${TRAVIS_BUILD_DIR}/.travis/build-condition.sh ${TRAVIS_COMMIT_RANGE}

ifeq ($(PROJECT), api)
PROJECT_NAME = hailstorm-api
PROJECT_PATH = ${TRAVIS_BUILD_DIR}/${PROJECT_NAME}
endif

ifeq ($(PROJECT), cli)
PROJECT_NAME = hailstorm-cli
PROJECT_PATH = ${TRAVIS_BUILD_DIR}/${PROJECT_NAME}
endif

ifeq ($(PROJECT), client-exchange)
PROJECT_NAME = hailstorm-client-exchange
PROJECT_PATH = ${TRAVIS_BUILD_DIR}/${PROJECT_NAME}
endif

ifeq ($(PROJECT), file-server)
PROJECT_NAME = hailstorm-file-server
PROJECT_PATH = ${TRAVIS_BUILD_DIR}/${PROJECT_NAME}
endif

ifeq ($(PROJECT), gem)
PROJECT_NAME = hailstorm-gem
PROJECT_PATH = ${TRAVIS_BUILD_DIR}/${PROJECT_NAME}
endif

ifeq ($(PROJECT), web-client)
PROJECT_NAME = hailstorm-web-client
PROJECT_PATH = ${TRAVIS_BUILD_DIR}/${PROJECT_NAME}
endif

ifeq ($(FORCE), yes)
CHANGES = ls -d
endif

install:
	if ${CHANGES} ${PROJECT_NAME}; then cd ${PROJECT_PATH} && make install; fi

test:
	if ${CHANGES} ${PROJECT_NAME}; then cd ${PROJECT_PATH} && make test; fi

coverage:
	cd ${PROJECT_PATH} && make coverage

integration:
	if ${CHANGES} ${PROJECT_NAME}; then cd ${PROJECT_PATH} && make integration; fi

publish:
	if ${CHANGES} ${PROJECT_NAME}; then cd ${PROJECT_PATH} && make publish; fi

package:
	if ${CHANGES} ${PROJECT_NAME}; then cd ${PROJECT_PATH} && make package; fi

build:
	if ${CHANGES} ${PROJECT_NAME}; then cd ${PROJECT_PATH} && make build; fi

install_aws:
	curl https://s3.amazonaws.com/aws-cli/awscli-bundle.zip -o awscli-bundle.zip
	unzip awscli-bundle.zip
	${TRAVIS_BUILD_DIR}/awscli-bundle/install -b ~/bin/aws
	export PATH=~/bin:${PATH}

cc_test_report:
	cd ${PROJECT_PATH} && make cc_test_report

local_publish:
	cd ${PROJECT_PATH} && make local_publish

hailstorm_site:
	cd ${TRAVIS_BUILD_DIR}/hailstorm-site && docker build -t hailstorm/hailstorm_site:1.0.0 .

hailstorm_agent:
	cd ${TRAVIS_BUILD_DIR}/setup/data-center && docker build -t hailstorm/hailstorm_agent:1.0.0 .

# file_server:
# 	cd hailstorm-file-server && \
# 	./gradlew clean bootJar docker

# web_client:
# 	cd hailstorm-web-client && npm run package
