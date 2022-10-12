#!/bin/bash
# Copyright 2022, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#  * Neither the name of NVIDIA CORPORATION nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

RET=0

LOG_DIR=${LOG_DIR:-"/logs"}
mkdir -p ${LOG_DIR}

TEST_LOG="${LOG_DIR}/response_cache_test.log"
UNIT_TEST=./response_cache_test

rm -fr *.log

# UNIT TEST
set +e
export CUDA_VISIBLE_DEVICES=0
LD_LIBRARY_PATH=/opt/tritonserver/lib:$LD_LIBRARY_PATH $UNIT_TEST >>$TEST_LOG 2>&1
if [ $? -ne 0 ]; then
    cat $TEST_LOG
    echo -e "\n***\n*** Response Cache Unit Test Failed\n***"
    RET=1
fi
set -e

# SERVER TESTS
mkdir -p "${PWD}/models/decoupled_cache/1"

# Check that server fails to start for a "decoupled" model with response
# cache enabled
SERVER=/opt/tritonserver/bin/tritonserver
SERVER_ARGS="--model-repository=${PWD}/models --response-cache-byte-size=8192"
SERVER_LOG="${LOG_DIR}/inference_server.log"
source ../common/util.sh
run_server
if [ "$SERVER_PID" != "0" ]; then
    echo -e "\n***\n*** Failed: $SERVER started successfully when it was expected to fail\n***"
    cat $SERVER_LOG
    RET=1

    kill $SERVER_PID
    wait $SERVER_PID
else
    # Check that server fails with the correct error message
    set +e
    grep -i "response cache does not currently support" ${SERVER_LOG} | grep -i "decoupled"
    if [ $? -ne 0 ]; then
        echo -e "\n***\n*** Failed: Expected response cache / decoupled mode error message in output\n***"
        cat $SERVER_LOG
        RET=1
    fi
    set -e
fi

if [ $RET -eq 0 ]; then
  echo -e "\n***\n*** Test Passed\n***"
else
  echo -e "\n***\n*** Test FAILED\n***"
fi

exit $RET
