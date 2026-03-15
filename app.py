#!/usr/bin/env python3
import base64
import json
import os
import sys
import time
import socket
from urllib.parse import urlparse

import requests
from kubernetes import client, config
from loguru import logger
import urllib3

# Suppress insecure request warnings for self-signed certs
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def get_kubernetes_client():
    try:
        config.load_incluster_config()
    except kubernetes.config.config_exception.ConfigException:
        config.load_kube_config()
    return client.CoreV1Api()

def get_unseal_keys(api_instance, secret_name, namespace):
    """Fetches and decodes unseal keys from the specified K8s secret."""
    try:
        secret = api_instance.read_namespaced_secret(name=secret_name, namespace=namespace)
        # K8s secrets are returned as base64 encoded strings in the .data dictionary
        keys = [base64.b64decode(v).decode('utf-8') for k, v in secret.data.items()]
        return keys
    except Exception as e:
        logger.error(f"Failed to read unseal keys from secret {secret_name}: {e}")
        return []

def unseal_node(vault_url, keys):
    """Submits unseal keys to a specific Vault node."""
    for key in keys:
        try:
            payload = {"key": key}
            response = requests.put(
                f"{vault_url}/v1/sys/unseal",
                data=json.dumps(payload),
                verify=False,
                timeout=5
            )
            status = response.json()
            if not status.get("sealed", True):
                logger.info(f"Node {vault_url} successfully unsealed.")
                return True
        except Exception as e:
            logger.error(f"Error sending unseal key to {vault_url}: {e}")
    return False

def get_vault_pods(api_instance, namespace, label_selector, max_retries):
    """Discovers Vault pods via label selector to get their internal IPs."""
    for _ in range(max_retries):
        pod_list = api_instance.list_namespaced_pod(namespace=namespace, label_selector=label_selector)
        
        # Filter for pods that have an IP assigned
        ready_pods = [pod for pod in pod_list.items if pod.status.pod_ip]
        if ready_pods:
            return ready_pods
        
        logger.warning("No Vault pods found with IPs yet. Retrying...")
        time.sleep(5)
    return []

if __name__ == "__main__":
    # Configuration from Environment Variables
    VAULT_URL = os.environ.get("VAULT_URL", "http://vault:8200")
    VAULT_KEYS_SECRET = os.environ.get("VAULT_KEYS_SECRET", "vault-unseal-keys")
    NAMESPACE = os.environ.get("NAMESPACE", "default")
    SCAN_DELAY = int(os.environ.get("VAULT_SCAN_DELAY", 30))
    LABEL_SELECTOR = os.environ.get("VAULT_LABEL_SELECTOR", "app.kubernetes.io/name=vault")
    MAX_RETRIES = int(os.environ.get("VAULT_POD_RETRIEVAL_MAX_RETRIES", 5))

    logger.info("Starting Vault Unsealer (Read-Only Mode)")
    
    k8s_api = get_kubernetes_client()
    url_parts = urlparse(VAULT_URL)
    port = url_parts.port or (443 if url_parts.scheme == "https" else 8200)

    while True:
        logger.info("Beginning unseal scan cycle...")
        
        # 1. Get the keys from the Secret
        unseal_keys = get_unseal_keys(k8s_api, VAULT_KEYS_SECRET, NAMESPACE)
        
        if not unseal_keys:
            logger.error("No unseal keys found. Skipping cycle.")
        else:
            # 2. Find Vault Pods
            pods = get_vault_pods(k8s_api, NAMESPACE, LABEL_SELECTOR, MAX_RETRIES)
            
            for pod in pods:
                pod_url = f"{url_parts.scheme}://{pod.status.pod_ip}:{port}"
                
                # 3. Check seal status
                try:
                    res = requests.get(f"{pod_url}/v1/sys/seal-status", verify=False, timeout=5)
                    status = res.json()
                    
                    if status.get("sealed"):
                        logger.info(f"Pod {pod.metadata.name} ({pod_url}) is SEALED. Unsealing...")
                        unseal_node(pod_url, unseal_keys)
                    else:
                        logger.debug(f"Pod {pod.metadata.name} is already unsealed.")
                        
                except Exception as e:
                    logger.error(f"Could not connect to Vault pod {pod.metadata.name}: {e}")

        time.sleep(SCAN_DELAY)
