# Description:
#   Reports Travis CI events

verifyTravis = require 'travisci-webhook-handler'
http = require 'https'
fs = require 'fs'
concat = require 'concat-stream'

room = '#pump.io'

module.exports = (robot) ->

  req = http.get 'https://api.travis-ci.org/config', (res) -> res.pipe sink

  req.on 'error', (err) ->
    robot.logger.error "Coudln't get Travis CI public key: #{err.message}"
    robot.messageRoom room, 'Coudln\'t get Travis CI public key.'

  sink = concat (buf) ->
    body = JSON.parse buf.toString()
    key = body.config.notifications.webhook.public_key

    handler = verifyTravis {
      path: '/hubot/travis-ci-events',
      public_key: key
    }

    # Extremely ugly hack because Hubot doesn't support middleware
    robot.router.stack.splice 2, 0, {
      route: '',
      handle: handler
    }

    handler.on 'success', (_event) ->
      # Throw the response on disk so we can debug
      # This is synchronous but I'll rip out this code soon anyway so I don't care.
      fs.writeFile(fs.mkdtempSync('/tmp/') + '/webhook-success.json', JSON.stringify(_event), {mode: 0o700})
      if event.committer_name is 'greenkeeper[bot]' then return

      event = _event.payload
      buildName = "#{event.repository.owner_name}/#{event.repository.name}##{event.number}"
      if event.pull_request
        buildInfo = "PR ##{event.pull_request_number} (\"#{event.pull_request_title}\")"
      else:
        buildInfo = event.branch
      buildInfo += " - #{event.commit.slice 0, 7} : #{event.committer_name}"

      robot.messageRoom room, "#{buildName} (#{buildInfo}): The build passed."

    handler.on 'failure', (_event) ->
      # Throw the response on disk so we can debug
      # This is synchronous but I'll rip out this code soon anyway so I don't care.
      fs.writeFile(fs.mkdtempSync('/tmp/') + '/webhook-failure.json', JSON.stringify(_event), {mode: 0o700})
      event = _event.payload
      buildName = "#{event.repository.owner_name}/#{event.repository.name}##{event.number}"
      if event.pull_request
        buildInfo = "PR ##{event.pull_request_number} (\"#{event.pull_request_title}\")"
      else:
        buildInfo = event.branch
      buildInfo += " - #{event.commit.slice 0, 7} : #{event.committer_name}"

      switch event.status_message
        when 'Passed'
          # TODO show only for new builds
          status = 'passed'
        when 'Fixed' then status = 'was fixed'
        when 'Broken' then status = 'was broken'
        when 'Failed' then status = 'failed'
        when 'Errored' then status = 'errored'
        else return

      robot.messageRoom room, "#{buildName} (#{buildInfo}): The build #{status}."
      robot.messageRoom room, "Build URL: #{event.build_url}"

    handler.on 'error', (err) ->
      robot.logger.error "Travis CI error occurred: #{err.message}"
      robot.messageRoom room, 'I need someone to check my logs; a Travis CI error occurred'
