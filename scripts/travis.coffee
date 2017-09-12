# Description:
#   Reports Travis CI events

verifyTravis = require 'travisci-webhook-handler'
http = require 'https'
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
      if event.committer_name is 'greenkeeper[bot]' then return

      event = _event.payload
      buildName = "#{event.repository.owner_name}/#{event.repository.name}##{event.number}"
      buildInfo = "#{event.branch} - #{event.commit.slice 0, 7} : #{event.committer_name}"

      robot.messageRoom room, "#{buildName} (#{buildInfo}): The build passed."

    handler.on 'failure', (_event) ->
      event = _event.payload
      buildName = "#{event.repository.owner_name}/#{event.repository.name}##{event.number}"
      buildInfo = "#{event.branch} - #{event.commit.slice 0, 7} : #{event.committer_name}"

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

    handler.on 'error', (err) ->
      robot.logger.error "Travis CI error occurred: #{err.message}"
      robot.messageRoom room, 'I need someone to check my logs; a Travis CI error occurred'
