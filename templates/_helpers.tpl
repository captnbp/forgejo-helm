{{/*
Create a default fully qualified postgresql name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "forgejo.postgresql.fullname" -}}
{{- include "common.names.dependency.fullname" (dict "chartName" "postgresql" "chartValues" .Values.postgresql "context" $) -}}
{{- end -}}

{{/*
Return the proper Forgejo image name
*/}}
{{- define "forgejo.image" -}}
{{- include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) -}}
{{- end -}}

{{/*
Return the proper image name (for the init container volume-permissions image)
*/}}
{{- define "forgejo.volumePermissions.image" -}}
{{- include "common.images.image" ( dict "imageRoot" .Values.volumePermissions.image "global" .Values.global ) -}}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "forgejo.imagePullSecrets" -}}
{{- include "common.images.pullSecrets" (dict "images" (list .Values.image .Values.volumePermissions.image) "global" .Values.global) -}}
{{- end -}}

{{/*
Return  the proper Storage Class
*/}}
{{- define "forgejo.storageClass" -}}
{{- include "common.storage.class" (dict "persistence" .Values.persistence "global" .Values.global) -}}
{{- end -}}

{{/*
Forgejo credential secret name
*/}}
{{- define "forgejo.secretName" -}}
{{- coalesce .Values.existingSecret (include "common.names.fullname" .) -}}
{{- end -}}

{{/*
Forgejo root URL
*/}}
{{- define "forgejo.rootURL" -}}
{{- if .Values.rootURL -}}
    {{- print .Values.rootURL -}}
{{- else if .Values.ingress.enabled -}}
    {{- printf "http://%s" .Values.ingress.hostname -}}
{{- else if (and (eq .Values.service.type "LoadBalancer") .Values.service.loadBalancerIP) -}}
    {{- $url := printf "http://%s" .Values.service.loadBalancerIP -}}
    {{- $port:= .Values.service.ports.http | toString }}
    {{- if (ne $port "80") -}}
        {{- $url = printf "%s:%s" $url $port -}}
    {{- end -}}
    {{- print $url -}}
{{- end -}}
{{- end -}}

{{/*
 Create the name of the service account to use
 */}}
{{- define "forgejo.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{- default (include "common.names.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
    {{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Forgejo credential secret name
*/}}
{{- define "forgejo.secretKey" -}}
{{- if .Values.existingSecret -}}
    {{- print .Values.existingSecretKey -}}
{{- else -}}
    {{- print "admin-password" -}}
{{- end -}}
{{- end -}}

{{/*
Return the SMTP Secret Name
*/}}
{{- define "forgejo.smtpSecretName" -}}
{{- if .Values.smtp.existingSecret }}
    {{- print .Values.smtp.existingSecret -}}
{{- else -}}
    {{- print (include "common.names.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the CNP cluster fullname
*/}}
{{- define "forgejo.cnp.fullname" -}}
{{- if .Values.postgresql.name -}}
{{- .Values.postgresql.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-postgresql" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Return the CNP cluster service name (read-write)
*/}}
{{- define "forgejo.cnp.serviceName" -}}
{{- printf "%s-rw" (include "forgejo.cnp.fullname" .) -}}
{{- end -}}

{{/*
Return the CNP secret name
*/}}
{{- define "forgejo.cnp.secretName" -}}
{{- if .Values.postgresql.database.existingSecret -}}
{{- .Values.postgresql.database.existingSecret -}}
{{- else -}}
{{- printf "%s-app" (include "forgejo.cnp.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the CNP database password
*/}}
{{- define "forgejo.cnp.password" -}}
{{- $secretData := (lookup "v1" "Secret" $.Release.Namespace (include "forgejo.cnp.secretName" .)).data }}
{{- if and $secretData (hasKey $secretData "password") }}
{{- index $secretData "password" | b64dec }}
{{- else }}
{{- randAlphaNum 32 }}
{{- end }}
{{- end -}}

{{/*
Get the database host
*/}}
{{- define "forgejo.database.host" -}}
{{- if .Values.postgresql.enabled -}}
{{- $releaseNamespace := .Release.Namespace }}
{{- $clusterDomain := .Values.clusterDomain }}
{{- $serviceName := include "forgejo.cnp.serviceName" . }}
{{- printf "%s.%s.svc.%s" $serviceName $releaseNamespace $clusterDomain -}}
{{- else -}}
{{- .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{/*
Get the database port
*/}}
{{- define "forgejo.database.port" -}}
{{- if .Values.postgresql.enabled -}}
5432
{{- else -}}
{{- .Values.externalDatabase.port -}}
{{- end -}}
{{- end -}}

{{/*
Get the database name
*/}}
{{- define "forgejo.database.name" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.database.name -}}
{{- else -}}
{{- .Values.externalDatabase.database -}}
{{- end -}}
{{- end -}}

{{/*
Get the database username
*/}}
{{- define "forgejo.database.username" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.database.username -}}
{{- else -}}
{{- .Values.externalDatabase.username -}}
{{- end -}}
{{- end -}}

{{/*
Get the Postgresql credentials secret.
*/}}
{{- define "forgejo.databaseSecretName" -}}
{{- if .Values.postgresql.enabled -}}
{{- include "forgejo.cnp.secretName" . -}}
{{- else -}}
{{- default (printf "%s-externaldb" .Release.Name) (tpl .Values.externalDatabase.existingSecret $) -}}
{{- end -}}
{{- end -}}

{{/*
Add environment variables to configure database values
*/}}
{{- define "forgejo.databaseSecretKey" -}}
{{- if .Values.postgresql.enabled -}}
    {{- print "password" -}}
{{- else -}}
    {{- if .Values.externalDatabase.existingSecret -}}
        {{- if .Values.externalDatabase.existingSecretPasswordKey -}}
            {{- printf "%s" .Values.externalDatabase.existingSecretPasswordKey -}}
        {{- else -}}
            {{- print "password" -}}
        {{- end -}}
    {{- else -}}
        {{- print "password" -}}
    {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return true if cert-manager required annotations for TLS signed certificates are set in the Ingress annotations
Ref: https://cert-manager.io/docs/usage/ingress/#supported-annotations
*/}}
{{- define "forgejo.ingress.certManagerRequest" -}}
{{ if or (hasKey . "cert-manager.io/cluster-issuer") (hasKey . "cert-manager.io/issuer") }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a TLS credentials secret object should be created
*/}}
{{- define "forgejo.createTlsSecret" -}}
{{- if and (not .Values.tls.existingSecret) .Values.tls.enabled }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return the TLS secret name
*/}}
{{- define "forgejo.issuerName" -}}
{{- $issuerName := .Values.tls.issuerRef.existingIssuerName -}}
{{- if $issuerName -}}
    {{- printf "%s" (tpl $issuerName $) -}}
{{- else -}}
    {{- printf "%s-http" (include "common.names.fullname" .) -}}
{{- end -}}
{{- end -}}
