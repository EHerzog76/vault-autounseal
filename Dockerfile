ARG DEBIAN_VERSION=13
ARG PYTHON_VERSION=3.12

FROM python:${PYTHON_VERSION}-slim AS build-env
LABEL description='Vaultauto-unseal for Kubernetes/Openshift/OKD'
ARG PYTHON_VERSION
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONFAULTHANDLER 1
ENV PYTHONUNBUFFERED 1
ENV VIRTUAL_ENV "/opt/venv"
COPY ./ /app
WORKDIR app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    gcc \
    libssl-dev \
    libpq-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install virtualenv \
    && virtualenv ${VIRTUAL_ENV}
# Create virtual environment
### Set up and activate virtual environment
#RUN python3 -m venv ${VIRTUAL_ENV} && ${VIRTUAL_ENV}/bin/pip install -U pip
###RUN python3 -m venv --copies $VIRTUAL_ENV && cd ${VIRTUAL_ENV}/bin/ && chmod a+x activate && ./activate && chmod a-x activate && cd -

ENV PATH "$VIRTUAL_ENV/bin:$PATH"
# install dependencies
#   --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org
#   use:  --user   to install in  /root/.local
#       --no-cache-dir --no-compile
RUN pip3 install --no-cache-dir --upgrade -r requirements.txt && rm -rf requirements.txt
#       pip3 install --no-cache-dir --no-compile pipenv && \
#       PIPENV_VENV_IN_PROJECT=1 pip install -r requirements.txt


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
ENV PYTHONPATH "${VIRTUAL_ENV}/lib/python${PYTHON_VERSION}/site-packages/"
ENV PATH "$VIRTUAL_ENV/bin:$PATH"

VOLUME /home/nonroot

COPY --from=build-env --chown=nonroot:nonroot /app /app
COPY --from=build-env --chown=nonroot:nonroot --exclude=**/__pycache__ --exclude=**/*.dist-info \
  --exclude=!**/*.dist-info/LICENSE* --exclude=!**/*.dist-info/licenses $VIRTUAL_ENV $VIRTUAL_ENV

WORKDIR /app

ENTRYPOINT ["python", "/app/app.py"]
