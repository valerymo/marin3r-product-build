#!/usr/bin/env bash

export MARIN3R_OPERATOR_IMAGE_PULLSPEC="quay.io/integreatly/marin3r-operator:v0.13.2"

export CSV_FILE=/manifests/marin3r.clusterserviceversion.yaml

sed -i -e "s|quay.io/3scale-sre/marin3r:v.*|\"${MARIN3R_OPERATOR_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"

export EPOC_TIMESTAMP=$(date +%s)
# time for some direct modifications to the csv
python3 - << CSV_UPDATE
import os
from collections import OrderedDict
from sys import exit as sys_exit
from datetime import datetime
from ruamel.yaml import YAML
yaml = YAML()
def load_manifest(pathn):
   if not pathn.endswith(".yaml"):
      return None
   try:
      with open(pathn, "r") as f:
         return yaml.load(f)
   except FileNotFoundError:
      print("File can not found")
      exit(2)

def dump_manifest(pathn, manifest):
   with open(pathn, "w") as f:
      yaml.dump(manifest, f)
   return
timestamp = int(os.getenv('EPOC_TIMESTAMP'))
datetime_time = datetime.fromtimestamp(timestamp)
csv_manifest = load_manifest(os.getenv('CSV_FILE'))
# Add arch and os support labels
csv_manifest['metadata']['labels'] = csv_manifest['metadata'].get('labels', {})
csv_manifest['metadata']['labels']['operatorframework.io/os.linux'] = 'supported'
csv_manifest['metadata']['annotations']['createdAt'] = datetime_time.strftime('%d %b %Y, %H:%M')
csv_manifest['metadata']['annotations']['features.operators.openshift.io/disconnected'] = 'true'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/fips-compliant'] = 'true'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/proxy-aware'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/tls-profiles'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/token-auth-aws'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/token-auth-azure'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/token-auth-gcp'] = 'false'
# Ensure that other annotations are accurate
csv_manifest['metadata']['annotations']['repository'] = 'https://github.com/3scale-ops/marin3r'
csv_manifest['metadata']['annotations']['containerImage'] = os.getenv('MARIN3R_OPERATOR_IMAGE_PULLSPEC', '')
csv_manifest['metadata']['annotations']['features.operators.openshift.io/cnf'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/cni'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/csi'] = 'false'

csv_manifest['metadata']['annotations']['olm.skipRange'] = '>=0.11.1 <0.13.2'

dump_manifest(os.getenv('CSV_FILE'), csv_manifest)
CSV_UPDATE

cat $CSV_FILE