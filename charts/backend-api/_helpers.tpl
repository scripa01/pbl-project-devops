{{- define "microservice.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "microservice.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
