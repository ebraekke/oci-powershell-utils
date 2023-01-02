
# TODO: parametrize and clean up 

[Text.Encoding]::Utf8.GetString([Convert]::FromBase64String('TW90w7ZyaGVhZA=='))

# Example 
# $S_ID points to secret bundle
# [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String((Get-OCISecretsSecretBundle -SecretId $S_ID).SecretBundleContent.Content))

