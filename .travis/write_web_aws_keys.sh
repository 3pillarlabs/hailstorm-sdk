#!/bin/sh

cat - > ${TRAVIS_BUILD_DIR}/hailstorm-web-client/e2e/data/keys.yml <<EOF
accessKey: ${AWS_ACCESS_KEY_ID}
secretKey: ${AWS_SECRET_ACCESS_KEY}
EOF
