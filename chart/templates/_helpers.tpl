{{/*定义应用名称*/}}
{{- define "deploy.name" }}
{{- $chart_name := .Chart.Name -}}
{{- print $chart_name -}}
{{- end }}


{{/*通用标签*/}}
{{- define "service.labels.standard" }}
app.kubernetes.io/name: {{ .Chart.Name | quote }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote}}
{{- end }}
helm.sh/chart: {{ .Chart.Name | quote }}
{{- end }}



{{/*通用注解*/}}
{{- define "service.annotations.standard" }}
app.kubernetes.io/name: {{ .Chart.Name | quote }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote}}
{{- end }}
helm.sh/chart: {{ .Chart.Name | quote }}
{{- end }}

{{/*日志 volumes*/}}
{{- define "log.volumes" }}
{{- if and (.Values.log.persistence.enabled) (not .Values.log.hostPath.enabled)}}
- name: log
  persistentVolumeClaim: 
    {{- if not .Values.log.persistence.existingClaim }}
    claimName: {{ include "deploy.name" . }}-log
    {{- else }}
    claimName: {{ .Values.log.persistence.existingClaim }}
    {{- end }} 
{{- end }} 
{{- if and (not .Values.log.persistence.enabled) (.Values.log.hostPath.enabled) }}
- name: log
  hostPath: 
    path: {{ .Values.log.hostPath.path }}
    type: {{ .Values.log.hostPath.type }}
{{- end }}
{{- end }}

{{/*时间同步 volumes*/}}
{{- define "time.volumes" }}
{{- if .Values.time.enabled }}
- name: host-time
  hostPath:
    path: /etc/localtime
    type: ''  
{{- end }}
{{- end }}


{{/* config volumes */}}
{{- define "configmap.volumes" -}}
{{- if .Values.configs.enabled -}}
{{- $configname := include "deploy.name" . }}
{{- range $file := .Values.configs.list }}
- name: {{ print $configname "-" $file.name | replace "." "-" }}
  configMap:
    name: {{ print $configname "-" $file.name | replace "." "-" }}
{{- end }}
{{- end -}}
{{- end -}}

{{/* config mount */}}
{{- define "configmap.mount" -}}
{{- if .Values.configs.enabled -}}
{{- $configname := include "deploy.name" . }}
{{- range $file := .Values.configs.list }}
- name: {{ print $configname "-" $file.name | replace "." "-" }}
  mountPath: {{ $file.path }}
{{- if $file.subPath }}
  subPath: {{ $file.subPath }}
{{- end }}
{{- end }}
{{- end -}}
{{- end -}}

