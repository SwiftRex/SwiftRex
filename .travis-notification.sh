#!/bin/sh

# https://testdriven.io/blog/getting-telegram-notifications-from-travis-ci/

# Get the token from Travis environment vars and build the bot URL:
BOT_URL="https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage"

# Set formatting for the message. Can be either "Markdown" or "HTML"
PARSE_MODE="Markdown"

# Use built-in Travis variables to check if all previous steps passed:
if [[ $TRAVIS_TEST_RESULT -ne 0 ]]; then
    emoji="💣"
    build_status="failed"
    link="[Job Log here](${TRAVIS_JOB_WEB_URL})"
else
    emoji="👍"
    build_status="succeeded"
    link=""
fi

# Define send message function. parse_mode can be changed to
# HTML, depending on how you want to format your message:
send_msg () {
    curl -s -X POST ${BOT_URL} \
        -d chat_id=$TELEGRAM_CHAT_ID \
        -d text="$1" \
        -d parse_mode=${PARSE_MODE}
}

# Send message to the bot with some pertinent details about the job
# Note that for Markdown, you need to escape any backtick (inline-code)
# characters, since they're reserved in bash
send_msg "
${emoji}
Travis build *${build_status}!*
\`Repository:  ${TRAVIS_REPO_SLUG}\`
\`Branch:      ${TRAVIS_BRANCH}\`

${TRAVIS_COMMIT_MESSAGE}
${link}
"

