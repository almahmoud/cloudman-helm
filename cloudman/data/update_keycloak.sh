#!/bin/sh

# abort if any command fails
set -e
username="admin"
{{- $message := "You must specify a password for Keycloak with --set keycloak.keycloak.password='mypassword' or by setting the key in a custom values.yaml" }}
password="{{ required $message .Values.keycloak.keycloak.password }}"

# get auth token
token=$(curl -k -s -d "client_id=admin-cli" -d "username=admin" -d "password=$password" -d "grant_type=password" \
       "{{ include "cloudman.root_url" . }}/auth/realms/master/protocol/openid-connect/token" | jq -r '.access_token')

# Get current brute force protection status
realm_protection=$(curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master | \
                   jq -r '.bruteForceProtected')

if [ "$realm_protection" = "false" ]
then
      
      # Add Brute Force Detection to Master realm
      curl -k -X PUT -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master -d '{"bruteForceProtected": true, "failureFactor": 5, "maxFailureWaitSeconds": 1800, "minimumQuickLoginWaitSeconds": 300}'

else
      echo "Brute Force Protection is already on."
fi

# get admin user id
user_id=$(curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/users/?username=admin | \
          jq -r '.[] | select(.username=="admin") | .id')

# get admin user email
user_email=$(curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/users/$user_id | \
jq -r '.email')

if [ "$user_email" = "null" ]
then
      # update admin user info
      updated_user=$(curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/users/$user_id | \
                jq -r '.firstName="{{ .Values.admin_firstname }}" | .lastName="{{ .Values.admin_lastname }}" | .email="{{ .Values.admin_email }}"')

      # Save new info
      curl -k -X PUT -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/users/$user_id -d "$updated_user"
else
      echo "The admin user already had an email address."
fi

cloudman_client=$(curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/clients | \
jq -r '.[] | select(.clientId=="cloudman")')

if [ -z "$cloudman_client" ]
then
      cloudman_client=$(cat <<EOF
{
    "clientId": "{{ .Values.cloudlaunch.cloudlaunchserver.extra_env.oidc_client_id }}",
    "rootUrl": "{{ include "cloudman.root_url" . }}/cloudman",
    "adminUrl": "{{ include "cloudman.root_url" . }}/cloudman",
    "enabled": true,
    "clientAuthenticatorType": "client-secret",
    "redirectUris": [
        "{{ include "cloudman.root_url" . }}/*"
    ],
    "webOrigins": [
        "{{ include "cloudman.root_url" . }}"
    ],
    "publicClient": true,
    "protocol": "openid-connect",
    "fullScopeAllowed": true,
    "protocolMappers": [
        {
            "name": "cloudman-audience",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-audience-mapper",
            "consentRequired": false,
            "config": {
                "included.client.audience": "{{ .Values.cloudlaunch.cloudlaunchserver.extra_env.oidc_client_id }}",
                "id.token.claim": "false",
                "access.token.claim": "true"
            }
        },
        {
            "name": "given name",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-usermodel-property-mapper",
            "consentRequired": false,
            "config": {
                "userinfo.token.claim": "true",
                "user.attribute": "firstName",
                "id.token.claim": "true",
                "access.token.claim": "true",
                "claim.name": "given_name",
                "jsonType.label": "String"
            }
        },
        {
            "name": "full name",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-full-name-mapper",
            "consentRequired": false,
            "config": {
                "id.token.claim": "true",
                "access.token.claim": "true",
                "userinfo.token.claim": "true"
            }
        },
        {
            "name": "role list",
            "protocol": "saml",
            "protocolMapper": "saml-role-list-mapper",
            "consentRequired": false,
            "config": {
                "single": "false",
                "attribute.nameformat": "Basic",
                "attribute.name": "Role"
            }
        },
        {
            "name": "username",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-usermodel-property-mapper",
            "consentRequired": false,
            "config": {
                "userinfo.token.claim": "true",
                "user.attribute": "username",
                "id.token.claim": "true",
                "access.token.claim": "true",
                "claim.name": "preferred_username",
                "jsonType.label": "String"
            }
        },
        {
            "name": "family name",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-usermodel-property-mapper",
            "consentRequired": false,
            "config": {
                "userinfo.token.claim": "true",
                "user.attribute": "lastName",
                "id.token.claim": "true",
                "access.token.claim": "true",
                "claim.name": "family_name",
                "jsonType.label": "String"
            }
        },
        {
            "name": "email",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-usermodel-property-mapper",
            "consentRequired": false,
            "config": {
                "userinfo.token.claim": "true",
                "user.attribute": "email",
                "id.token.claim": "true",
                "access.token.claim": "true",
                "claim.name": "email",
                "jsonType.label": "String"
            }
        }
    ]
}
EOF
      )

      # Add CloudMan client
      curl -k -X POST -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" . }}/auth/admin/realms/master/clients -d "$cloudman_client"
else
      echo "The cloudman client already exists."
fi

{{- range $key, $chart := .Values.helmsman_config.charts -}}
{{- if $chart.oidc_client -}}
{{- $client_id := tpl $chart.oidc_client.client_id $ -}}
{{- $redirect_uris := "" }}
{{- range $index, $uri := $chart.oidc_client.redirect_uris }}
{{- if $index }}
{{- $redirect_uris = print $redirect_uris ", " }}
{{- end }}
{{- $redirect_uris = print $redirect_uris (tpl $uri $ | quote) }}
{{- end }}

{{ $key }}_client=$(curl -k -s -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" $ }}/auth/admin/realms/master/clients | \
jq -r '.[] | select(.clientId=="$client_id")')

if [ -z "${{ $key }}_client" ]
then
      {{ $key }}_client=$(cat <<EOF
{
    "clientId": {{ $client_id | quote }},
    "enabled": true,
    "clientAuthenticatorType": "client-secret",
    "redirectUris": [{{ $redirect_uris }}],
    {{- if $chart.oidc_client.public_client }}
    {{- $client_secret := tpl (required "The client secret is required if the client is not public" $chart.oidc_client.client_secret) $ }}
    "publicClient": false,
    "secret": {{ $client_secret | quote }},
    {{- else }}
    "publicClient": true,
    {{- end }}
    "protocol": "openid-connect",
    "fullScopeAllowed": true,
    "protocolMappers": [
        {
            "name": "{{ $client_id }}-audience",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-audience-mapper",
            "consentRequired": false,
            "config": {
                "included.client.audience": {{ $client_id | quote }},
                "id.token.claim": "false",
                "access.token.claim": "true"
            }
        }
    ]
}
EOF
      )

      # add new client
      curl -k -X POST -H "Content-Type: application/json" -H "Authorization: bearer $token" {{ include "cloudman.root_url" $ }}/auth/admin/realms/master/clients -d "${{ $key }}_client"

else
      echo "The {{ $client_id }} client already exists."
fi

{{- end -}}
{{- end -}}
