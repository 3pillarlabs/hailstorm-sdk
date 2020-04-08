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

DOCKER_COMPOSE_PREFIX := hailstorm-sdk_

DOCKER_NETWORK := hailstorm

ifeq ($(COMPOSE), cli-verify)
COMPOSE_FILES := -f docker-compose-cli.yml -f docker-compose-cli.ci.yml -f docker-compose.dc-sim.yml
endif

ifeq ($(COMPOSE), cli)
COMPOSE_FILES := -f docker-compose-cli.yml
endif

ifeq ($(COMPOSE), web-client-verify)
COMPOSE_FILES := -f docker-compose.yml -f docker-compose.dc-sim.yml -f docker-compose.web-ci.yml
endif

ifeq ($(COMPOSE), web)
COMPOSE_FILES := -f docker-compose.yml
endif

SITE_INSTANCE_ID = $$(cat ~/.SITE_INSTANCE_ID 2> /dev/null)

SITE_STATUS_CHECK = aws ec2 describe-instance-status --instance-ids "${SITE_INSTANCE_ID}" \
                    --query "join(' ', InstanceStatuses[0].[ \
						InstanceState.Name, \
					    InstanceStatus.Details[0].Status, \
						SystemStatus.Details[0].Status \
					])" | perl -ne '/^"(.+)"$$/; print $$1' | grep -v '^running passed passed$$' > /dev/null


WEB_DEPENDENCY_CHANGES =	${CHANGES} hailstorm-web-client; \
							if [ $$? -eq 0 ]; then \
								echo yes; \
							else \
								${CHANGES} hailstorm-api; \
								if [ $$? -eq 0 ]; then \
									echo yes; \
								else \
									${CHANGES} hailstorm-file-server; \
									if [ $$? -eq 0 ]; then \
										echo yes; \
									else \
										${CHANGES} hailstorm-client-exchange; \
										if [ $$? -eq 0 ]; then \
											echo yes; \
										fi; \
									fi; \
								fi; \
							fi

# $(call docker_image_id,project_dir)
define docker_image_id
$(shell cd $1 && make docker_image_id)
endef

RELEASE_VERSION = $(shell cat VERSION)

GIT_RELEASE_TAG = $(shell git tag --list 'releases/${RELEASE_VERSION}')

install:
	if ${CHANGES} ${PROJECT_NAME}; then cd ${PROJECT_PATH} && make install; fi

test:
	if ${CHANGES} ${PROJECT_NAME}; then cd ${PROJECT_PATH} && make test; fi

coverage:
	cd ${PROJECT_PATH} && make coverage

integration:
	if ${CHANGES} ${PROJECT_NAME}; then cd ${PROJECT_PATH} && make integration; fi

package:
	if ${CHANGES} ${PROJECT_NAME}; then cd ${PROJECT_PATH} && make package; fi

build:
	if ${CHANGES} ${PROJECT_NAME}; then cd ${PROJECT_PATH} && make build; fi

publish:
	if ${TRAVIS_BUILD_DIR}/.travis/new-dcr-tag.sh $(call docker_image_id,${PROJECT_NAME}); then \
		cd ${PROJECT_PATH} && make publish; \
	fi


install_aws:
	set -ev
	curl https://s3.amazonaws.com/aws-cli/awscli-bundle.zip -o awscli-bundle.zip
	unzip awscli-bundle.zip
	${TRAVIS_BUILD_DIR}/awscli-bundle/install -b ~/bin/aws


cc_test_report:
	cd ${PROJECT_PATH} && make cc_test_report


local_publish:
	cd ${PROJECT_PATH} && make local_publish


hailstorm_site:
	cd ${TRAVIS_BUILD_DIR}/hailstorm-site && docker build -t hailstorm3/hailstorm-site .


hailstorm_agent:
	cd ${TRAVIS_BUILD_DIR}/setup/data-center && docker build -t hailstorm3/hailstorm-agent .


hailstorm_site_instance:
	set -ev
	make install_aws
	${TRAVIS_BUILD_DIR}/.travis/write_aws_profile.sh
	aws ec2 run-instances \
	--image-id ${HAILSTORM_SITE_AMI_ID} \
	--instance-type t2.medium \
	--key-name ${AWS_SITE_KEY_PAIR} \
	--security-group-ids ${AWS_SITE_SECURITY_GROUP} \
	--subnet-id ${AWS_SITE_SUBNET_ID} \
	--associate-public-ip-address \
	--tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value='$${TAG_VALUE}'}]" \
	--query 'Instances[0].InstanceId' | perl -ne '/^"(.+)"$$/; print $$1' > ~/.SITE_INSTANCE_ID


docker_compose_binary:
	set -ev
	sudo curl -fsL -o /usr/local/bin/docker-compose \
	"https://github.com/docker/compose/releases/download/1.25.4/docker-compose-Linux-x86_64"
	sudo chmod +x /usr/local/bin/docker-compose


ready_hailstorm_site:
	while ${SITE_STATUS_CHECK}; do \
		echo "Waiting for ${SITE_INSTANCE_ID} running state"; \
		sleep 30; \
	done


cli_integration_before_install_steps:
	set -ev
	make hailstorm_site_instance
	${TRAVIS_BUILD_DIR}/.travis/write_cli_aws_keys.sh
	make docker_compose_binary
	if [ -n "${TRAVIS}" ]; then sudo systemctl stop mysql; fi


cli_integration_before_install:
	if ${CHANGES} hailstorm-cli; then make cli_integration_before_install_steps; fi


cli_install_steps:
	set -ev
	make PROJECT=gem FORCE=yes install build local_publish
	mkdir -p ${TRAVIS_BUILD_DIR}/hailstorm-cli/pkg
	cp ${TRAVIS_BUILD_DIR}/hailstorm-gem/pkg/hailstorm-*.gem ${TRAVIS_BUILD_DIR}/hailstorm-cli/pkg/.
	make PROJECT=cli FORCE=yes install build package


cli_integration_install_steps:
	set -ev
	if ${TRAVIS_BUILD_DIR}/.travis/new-dcr-tag.sh $(call docker_image_id,hailstorm-cli); then \
		make cli_install_steps; \
	fi
	docker-compose ${COMPOSE_FILES} up -d
	make ready_hailstorm_site


cli_integration_install:
	if ${CHANGES} hailstorm-cli; then make cli_integration_install_steps; fi


cli_integration_after_script:
	if ${CHANGES} hailstorm-cli; then \
		aws ec2 terminate-instances --instance-ids "${SITE_INSTANCE_ID}"; \
		docker-compose ${COMPOSE_FILES} down; \
	fi


web_integration_before_install_steps:
	set -ev
	make hailstorm_site_instance
	${TRAVIS_BUILD_DIR}/.travis/write_web_aws_keys.sh
	make docker_compose_binary
	if [ -n "${TRAVIS}" ]; then sudo systemctl stop mysql; fi


web_integration_before_install:
	if [ -n "$$(${WEB_DEPENDENCY_CHANGES})" ]; then make web_integration_before_install_steps; fi


api_package:
	set -ev
	make PROJECT=gem FORCE=yes install build local_publish
	mkdir -p ${TRAVIS_BUILD_DIR}/hailstorm-api/pkg
	cp ${TRAVIS_BUILD_DIR}/hailstorm-gem/pkg/hailstorm-*.gem ${TRAVIS_BUILD_DIR}/hailstorm-api/pkg/.
	make PROJECT=api FORCE=yes install package


web_integration_install_steps:
	set -ev
	if ${TRAVIS_BUILD_DIR}/.travis/new-dcr-tag.sh $(call docker_image_id,hailstorm-web-client); then \
		make PROJECT=web-client FORCE=yes install build package; \
	fi

	if ${TRAVIS_BUILD_DIR}/.travis/new-dcr-tag.sh $(call docker_image_id,hailstorm-api); then \
		make api_package; \
	fi

	if ${TRAVIS_BUILD_DIR}/.travis/new-dcr-tag.sh $(call docker_image_id,hailstorm-file-server); then \
		make PROJECT=file-server FORCE=yes install package; \
	fi

	if ${TRAVIS_BUILD_DIR}/.travis/new-dcr-tag.sh $(call docker_image_id,hailstorm-client-exchange); then \
		make PROJECT=client-exchange FORCE=yes install package; \
	fi

	docker-compose ${COMPOSE_FILES} up -d
	# wait for docker containers to initialize - TODO: periodically check docker logs
	sleep 180
	make ready_hailstorm_site


web_integration_install:
	if [ -n "$$(${WEB_DEPENDENCY_CHANGES})" ]; then make web_integration_install_steps; fi


web_integration_script:
	if [ -n "$$(${WEB_DEPENDENCY_CHANGES})" ]; then make PROJECT=web-client FORCE=yes integration; fi


web_integration_after_script:
	if [ -n "$$(${WEB_DEPENDENCY_CHANGES})" ]; then \
		aws ec2 terminate-instances --instance-ids "${SITE_INSTANCE_ID}"; \
		docker-compose ${COMPOSE_FILES} down; \
	fi


publish_web_packages:
	for component in web-client api file-server client-exchange; do \
		make PROJECT=$${component} publish; \
	done


release_tag:
	if [ -z "${GIT_RELEASE_TAG}" ]; then \
		git tag -a "releases/${RELEASE_VERSION}" -m "'Release tag ${RELEASE_VERSION}'"; \
	fi


docker_compose_up:
	docker-compose ${COMPOSE_FILES} up -d


docker_compose_down:
	docker-compose ${COMPOSE_FILES} down


cli_integration_up:
	make COMPOSE=cli-verify docker_compose_up


cli_integration_down:
	make COMPOSE=cli-verify docker_compose_down


web_integration_up:
	make COMPOSE=web-client-verify docker_compose_up


web_integration_down:
	make COMPOSE=web-client-verify docker_compose_down
