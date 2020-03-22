#!/bin/sh

cat - > ${TRAVIS_BUILD_DIR}/hailstorm-web-client/e2e/data/keys.yml <<EOF
access_key: ${AWS_ACCESS_KEY_ID}
secret_key: ${AWS_SECRET_ACCESS_KEY}
EOF
