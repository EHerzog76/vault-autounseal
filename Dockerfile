ARG DEBIAN_VERSION=13
ARG PYTHON_VERSION=3.12
FROM python:${PYTHON_VERSION}-slim AS build-env
LABEL description='Vaultauto-unseal for Kubernetes/Openshift/OKD'
ARG PYTHON_VERSION
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONFAULTHANDLER 1
ENV PYTHONUNBUFFERED 1
COPY ./ /app
WORKDIR app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*
# Create virtual environment
### Set up and activate virtual environment
ENV VIRTUAL_ENV "/opt/venv"
RUN python3 -m venv ${VIRTUAL_ENV} && ${VIRTUAL_ENV}/bin/pip install -U pip
#RUN python3 -m venv --copies $VIRTUAL_ENV && cd ${VIRTUAL_ENV}/bin/ && chmod a+x activate && ./activate && chmod a-x activate && cd -
ENV PATH "$VIRTUAL_ENV/bin:$PATH"
# install dependencies
#   use:  --user   to install in  /root/.local
#	--no-cache-dir --no-compile
RUN ${VIRTUAL_ENV}/bin/pip install --no-cache-dir --upgrade -r requirements.txt && rm -rf requirements.txt
#	pip3 install --no-cache-dir --no-compile pipenv && \
#	PIPENV_VENV_IN_PROJECT=1 pip install -r requirements.txt


FROM gcr.io/distroless/python3-debian${DEBIAN_VERSION}:nonroot
ARG PYTHON_VERSION
ENV VIRTUAL_ENV "/opt/venv"
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONFAULTHANDLER 1
ENV PYTHONUNBUFFERED 1
ENV VAULT_URL ""
ENV VAULT_SECRET_SHARES ""
ENV VAULT_SECRET_THRESHOLD ""
ENV NAMESPACE ""
ENV VAULT_KEYS_SECRET ""
ENV PYTHONWARNINGS "ignore:Unverified HTTPS request"
#ENV PYTHONPATH /usr/local/lib/python${PYTHON_VERSION}/site-packages
ENV PYTHONPATH "${VIRTUAL_ENV}/lib/python${PYTHON_VERSION}/site-packages/"
ENV PATH "$VIRTUAL_ENV/bin:$PATH"

COPY --from=build-env --chown=nonroot:nonroot /app /app
COPY --from=build-env --chown=nonroot:nonroot $VIRTUAL_ENV $VIRTUAL_ENV
#COPY --from=build-env /usr/local/lib/python${PYTHON_VERSION}/site-packages /usr/local/lib/python${PYTHON_VERSION}/site-packages

WORKDIR /app

ENTRYPOINT ["/opt/venv/bin/python", "/app/app.py"]
