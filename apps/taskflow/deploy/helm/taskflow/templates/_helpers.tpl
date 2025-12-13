{{/*
Expand the name of the chart.
*/}}
{{- define "taskflow.name" -}}
{{- default .Chart.Name .Values.global.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "taskflow.fullname" -}}
{{- if .Values.global.fullnameOverride }}
{{- .Values.global.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.global.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "taskflow.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "taskflow.labels" -}}
helm.sh/chart: {{ include "taskflow.chart" . }}
{{ include "taskflow.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "taskflow.selectorLabels" -}}
app.kubernetes.io/name: {{ include "taskflow.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
API labels
*/}}
{{- define "taskflow.api.labels" -}}
{{ include "taskflow.labels" . }}
app.kubernetes.io/component: api
{{- end }}

{{/*
API selector labels
*/}}
{{- define "taskflow.api.selectorLabels" -}}
{{ include "taskflow.selectorLabels" . }}
app.kubernetes.io/component: api
{{- end }}

{{/*
Worker labels
*/}}
{{- define "taskflow.worker.labels" -}}
{{ include "taskflow.labels" . }}
app.kubernetes.io/component: worker
{{- end }}

{{/*
Worker selector labels
*/}}
{{- define "taskflow.worker.selectorLabels" -}}
{{ include "taskflow.selectorLabels" . }}
app.kubernetes.io/component: worker
{{- end }}

{{/*
Cron labels
*/}}
{{- define "taskflow.cron.labels" -}}
{{ include "taskflow.labels" . }}
app.kubernetes.io/component: cron
{{- end }}

{{/*
Cron selector labels
*/}}
{{- define "taskflow.cron.selectorLabels" -}}
{{ include "taskflow.selectorLabels" . }}
app.kubernetes.io/component: cron
{{- end }}

{{/*
Migration labels
*/}}
{{- define "taskflow.migration.labels" -}}
{{ include "taskflow.labels" . }}
app.kubernetes.io/component: migration
{{- end }}

{{/*
PostgreSQL labels
*/}}
{{- define "taskflow.postgresql.labels" -}}
{{ include "taskflow.labels" . }}
app.kubernetes.io/component: postgresql
{{- end }}

{{/*
PostgreSQL selector labels
*/}}
{{- define "taskflow.postgresql.selectorLabels" -}}
{{ include "taskflow.selectorLabels" . }}
app.kubernetes.io/component: postgresql
{{- end }}

{{/*
Redis labels
*/}}
{{- define "taskflow.redis.labels" -}}
{{ include "taskflow.labels" . }}
app.kubernetes.io/component: redis
{{- end }}

{{/*
Redis selector labels
*/}}
{{- define "taskflow.redis.selectorLabels" -}}
{{ include "taskflow.selectorLabels" . }}
app.kubernetes.io/component: redis
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "taskflow.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "taskflow.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
API image
*/}}
{{- define "taskflow.api.image" -}}
{{- $tag := .Values.api.image.tag | default .Chart.AppVersion }}
{{- printf "%s:%s" .Values.api.image.repository $tag }}
{{- end }}

{{/*
Worker image
*/}}
{{- define "taskflow.worker.image" -}}
{{- $tag := .Values.worker.image.tag | default .Chart.AppVersion }}
{{- printf "%s:%s" .Values.worker.image.repository $tag }}
{{- end }}

{{/*
Cron image
*/}}
{{- define "taskflow.cron.image" -}}
{{- $tag := .Values.cron.image.tag | default .Chart.AppVersion }}
{{- printf "%s:%s" .Values.cron.image.repository $tag }}
{{- end }}

{{/*
Migration image
*/}}
{{- define "taskflow.migration.image" -}}
{{- $tag := .Values.migration.image.tag | default .Chart.AppVersion }}
{{- printf "%s:%s" .Values.migration.image.repository $tag }}
{{- end }}

{{/*
PostgreSQL connection URL
*/}}
{{- define "taskflow.postgresql.url" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "postgresql://%s:%s@%s-postgresql:%d/%s" .Values.postgresql.auth.username .Values.postgresql.auth.password (include "taskflow.fullname" .) (.Values.postgresql.service.port | int) .Values.postgresql.auth.database }}
{{- end }}
{{- end }}

{{/*
Redis connection URL
*/}}
{{- define "taskflow.redis.url" -}}
{{- if .Values.redis.enabled }}
{{- if .Values.redis.auth.enabled }}
{{- printf "redis://:%s@%s-redis:%d/0" .Values.redis.auth.password (include "taskflow.fullname" .) (.Values.redis.service.port | int) }}
{{- else }}
{{- printf "redis://%s-redis:%d/0" (include "taskflow.fullname" .) (.Values.redis.service.port | int) }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common environment variables
*/}}
{{- define "taskflow.commonEnv" -}}
- name: DATABASE_URL
  value: {{ include "taskflow.postgresql.url" . | quote }}
- name: REDIS_URL
  value: {{ include "taskflow.redis.url" . | quote }}
- name: LOG_LEVEL
  value: {{ .Values.config.logLevel | quote }}
- name: ENVIRONMENT
  value: {{ .Values.config.environment | quote }}
{{- if .Values.telemetry.enabled }}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ .Values.telemetry.endpoint | quote }}
- name: OTEL_SERVICE_NAME
  value: {{ .Values.telemetry.serviceName | quote }}
- name: OTEL_SERVICE_VERSION
  value: {{ .Values.telemetry.serviceVersion | quote }}
- name: OTEL_RESOURCE_ATTRIBUTES
  value: {{ printf "environment=%s" .Values.telemetry.environment | quote }}
{{- end }}
{{- end }}
