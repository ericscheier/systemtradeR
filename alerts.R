# regenerate slack token: https://api.slack.com/docs/oauth-test-tokens

slackr_setup(config_file=paste0(getwd(),"/.slackr"), echo=TRUE)

slackr_setup(channel = "#reports", username="slackr"
             , incoming_webhook_url="https://hooks.slack.com/services/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"
             , api_token="<slack-key-removed-a51b60f1>"
             , echo=TRUE)
