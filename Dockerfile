FROM python:3.11-slim AS build-env
LABEL description='Vaultauto-unseal for Kubernetes/Openshift/OKD'
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONFAULTHANDLER 1
ENV PYTHONUNBUFFERED 1
COPY ./ /app
WORKDIR app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir --upgrade -r requirements.txt  && rm -rf requirements.txt

FROM gcr.io/distroless/python3:nonroot
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONFAULTHANDLER 1
ENV PYTHONUNBUFFERED 1
ENV PYTHONPATH=/usr/local/lib/python3.9/site-packages
ENV VAULT_URL ""
ENV VAULT_SECRET_SHARES ""
ENV VAULT_SECRET_THRESHOLD ""
ENV NAMESPACE ""
ENV VAULT_KEYS_SECRET ""
ENV PYTHONWARNINGS "ignore:Unverified HTTPS request"

COPY --from=build-env /app /app
COPY --from=build-env /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages
WORKDIR /app

ENTRYPOINT ["python", "/app/app.py.py"]
