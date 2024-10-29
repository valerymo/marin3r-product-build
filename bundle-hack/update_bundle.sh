#!/usr/bin/env bash

#export MARIN3R_MARIN3R_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/api-management-tenant/marin3r/marin3r-operator@sha256:4632bc387e54960ce0bb0fdb4fdda89dbc8c7afc16c2427ff6e517fb47379256"

export MARIN3R_OPERATOR_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/api-management-tenant/marin3r/marin3r-operator@sha256:aa395edded8dde4a38e1033fa47e2fad6fa0bebc1aa0889d5da47afcb8f34267"

export CSV_FILE=/manifests/marin3r.clusterserviceversion.yaml

sed -i -e "s|quay.io/3scale/marin3r:v.*|\"${MARIN3R_MARIN3R_IMAGE_PULLSPEC}\"|g" \
	-e "s|quay.io/3scale/marin3r:v.*|\"${MARIN3R_OPERATOR_IMAGE_PULLSPEC}\"|g" \
	"${CSV_FILE}"

export AMD64_BUILT=$(skopeo inspect --raw docker://${MARIN3R_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="amd64")')
export ARM64_BUILT=$(skopeo inspect --raw docker://${MARIN3R_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="arm64")')
export PPC64LE_BUILT=$(skopeo inspect --raw docker://${MARIN3R_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="ppc64le")')
export S390X_BUILT=$(skopeo inspect --raw docker://${MARIN3R_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="s390x")')

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
if os.getenv('AMD64_BUILT'):
	csv_manifest['metadata']['labels']['operatorframework.io/arch.amd64'] = 'supported'
if os.getenv('ARM64_BUILT'):
	csv_manifest['metadata']['labels']['operatorframework.io/arch.arm64'] = 'supported'
if os.getenv('PPC64LE_BUILT'):
	csv_manifest['metadata']['labels']['operatorframework.io/arch.ppc64le'] = 'supported'
if os.getenv('S390X_BUILT'):
	csv_manifest['metadata']['labels']['operatorframework.io/arch.s390x'] = 'supported'
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

# Ensure that any parameters are properly defined in the spec if you do not want to
# put them in the CSV itself
with open(f"{__dir}/DESCRIPTION", "r") as desc_file:
    description = desc_file.read()

with open(f"{__dir}/ICON", "r") as icon_file:
    icon_data = icon_file.read()

csv_manifest['spec']['description'] = description
csv_manifest['spec']['icon'][0]['base64data'] = icon_data


# Make sure that our latest nudged references are properly configured in the spec.relatedImages
# NOTE: the names should be unique
csv_manifest['spec']['relatedImages'] = [
   {'name': 'marin3r-operator', 'image': os.getenv('MARIN3R_OPERATOR_IMAGE_PULLSPEC')}
]

dump_manifest(os.getenv('CSV_FILE'), csv_manifest)
CSV_UPDATE

cat $CSV_FILE