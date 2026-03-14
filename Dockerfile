ARG DEBIAN_VERSION=13
ARG PYTHON_VERSION=3.11
FROM python:${PYTHON_VERSION}-slim AS build-env
LABEL description='Vaultauto-unseal for Kubernetes/Openshift/OKD'
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONFAULTHANDLER 1
ENV PYTHONUNBUFFERED 1
COPY ./ /app
WORKDIR app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*
# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir --upgrade -r requirements.txt  && rm -rf requirements.txt

FROM gcr.io/distroless/python3-debian${DEBIAN_VERSION}:nonroot
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONFAULTHANDLER 1
ENV PYTHONUNBUFFERED 1
ENV PYTHONPATH=/usr/local/lib/python${PYTHON_VERSION}/site-packages
ENV VAULT_URL ""
ENV VAULT_SECRET_SHARES ""
ENV VAULT_SECRET_THRESHOLD ""
ENV NAMESPACE ""
ENV VAULT_KEYS_SECRET ""
ENV PYTHONWARNINGS "ignore:Unverified HTTPS request"
ENV PATH="/opt/venv/bin:$PATH"

COPY --from=build-env /app /app
COPY --from=build-env /opt/venv /opt/venv

COPY --from=build-env /usr/local/lib/python${PYTHON_VERSION}/site-packages /usr/local/lib/python${PYTHON_VERSION}/site-packages
WORKDIR /app

ENTRYPOINT ["python3", "/app/app.py.py"]
