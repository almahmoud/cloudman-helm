{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "cloudman.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "cloudman.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cloudman.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Rancher config settings
*/}}
{{- define "cloudman.cluster_config" -}}
{{- if .Values.cm_initial_cluster_data -}}
{{ .Values.cm_initial_cluster_data | b64dec }}
{{- end -}}
rancher_config:
  rancher_url: {{ .Values.rancher_url }}
  rancher_api_key: {{ .Values.rancher_api_key }}
  rancher_cluster_id: {{ .Values.rancher_cluster_id }}
  rancher_project_id: {{ .Values.rancher_project_id }}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "keycloak_data.name" -}}
{{- printf "%s-keycloak" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Generate an ID for KeyCloak objects.
*/}}
{{- define "keycloak_data.random_id" -}}
{{- printf "%s-%s-%s-%s-%s" (randAlphaNum 8) (randAlphaNum 4) (randAlphaNum 4) (randAlphaNum 4) (randAlphaNum 12) | lower -}}
{{- end -}}
