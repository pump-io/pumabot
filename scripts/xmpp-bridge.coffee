# Description:
#   Says where the source is.

# Not inline for perf
bridgeRegexp = /\[(.*)\] (.*)/

module.exports = (robot) ->

	robot.receiveMiddleware (context, next, done) ->
		if context.response.message.user.name is 'xmpp-pump'
			result = bridgeRegexp.exec context.response.message.text

			if result
				context.response.message.user.name = result[1]
				context.response.message.text = result[2]
			else
				# TODO: handle this

		next(done)
