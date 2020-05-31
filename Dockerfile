#FROM lambci/lambda:build-python3.7
ARG DOCKER_MIRROR=''
FROM ${DOCKER_MIRROR}lambci/lambda:build-python3.7

WORKDIR /root

RUN pip3 install -t /root/to_zip/python cloudformation-cli && \
cd /root/to_zip; zip -9yr /root/layer.zip . && \
cd python; python3 -c "import rpdk.core; print(rpdk.core.__version__)" > /root/VERSION
