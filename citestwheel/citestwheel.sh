#!/usr/bin/env bash

set -eoxu pipefail

export RAPIDS_WHEEL_VER_OVERRIDE="${RAPIDS_WHEEL_VER_OVERRIDE:-}"
export CIBW_TEST_EXTRAS="${CIBW_TEST_EXTRAS:-}"
export CIBW_TEST_REQUIRES="${CIBW_TEST_REQUIRES:-}"

rm -rf ./dist
mkdir -p ./dist

first='yes'
arch=$(uname -m)

for pyver in ${RAPIDS_PY_VER}; do
        deactivate || true

        pyunittest="cp${pyver//./}-cp${pyver//./}"

        /opt/python/$pyunittest/bin/python -m venv /cibw-unittest-venv-${pyver}
        . /cibw-unittest-venv-${pyver}/bin/activate

        curl -sS https://bootstrap.pypa.io/get-pip.py | python3

        if [ "${first}" == "yes" ]; then
                python -m pip install awscli
                rapids-download-wheels-from-s3 ./dist
                first='no'
        fi

        if [ "${RAPIDS_WHEEL_VER_OVERRIDE}" != "" ]; then
                python3 -m pip install --verbose ./dist/${RAPIDS_PY_WHEEL_NAME}*-${RAPIDS_WHEEL_VER_OVERRIDE}.whl
        else
                python3 -m pip install --verbose ./dist/${RAPIDS_PY_WHEEL_NAME}*-cp${pyver//./}-cp${pyver//./}*_$(uname -m).whl
        fi

        python3 -m pip check

        if [ "${arch}" == "x86_64" ]; then
                sh -c "${RAPIDS_BEFORE_TEST_COMMANDS_AMD64}"
        elif [ "${arch}" == "aarch64" ]; then
                sh -c "${RAPIDS_BEFORE_TEST_COMMANDS_ARM64}"
        fi

        if [ "${CIBW_TEST_REQUIRES}" != "" ]; then
                pip install ${CIBW_TEST_REQUIRES}
        fi

        # see: https://cibuildwheel.readthedocs.io/en/stable/options/#test-extras
        if [ "${CIBW_TEST_EXTRAS}" != "" ]; then
                pip install ./dist/*.whl[${CIBW_TEST_EXTRAS}]
        else
                pip install ./dist/*.whl
        fi

        sh -c "${CIBW_TEST_COMMAND}"

        python3 -c "${RAPIDS_WHEEL_SMOKETEST_COMMAND}"
done

rapids-upload-wheels-to-s3 ./dist
