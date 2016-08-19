# Description:
#   Helps to run the monthly meeting.
#
# Commands:
#   hubot start meeting - announces the meeting start and the beginning of logging, and starts roll call
#   hubot end meeting - thanks participants for coming and announces the end of the log

module.exports = (robot) ->
	robot.respond /start meeting/i, (res) ->
		res.reply res.random ['just a sec', 'no problem', 'sure']
		# TODO: ping all
		res.send '#############################################################'
		res.send 'BEGIN LOG'
		res.send '#############################################################'
		res.send 'Welcome to this month\'s Pump.io community meeting! Everyone is welcome to participate.'
		res.send 'This meeting is being logged and it will be posted on the wiki. If you would like your nick redacted, please say so, either now or after the meeting.'
		res.send 'Let\'s start with roll call - who\'s here?'
		res.emote 'is here'

	robot.respond /end meeting/i, (res) ->
		res.send 'Thank you all for attending! Logs will be posted on the wiki shortly.'
		res.send 'See you next month!'
		res.send '#############################################################'
		res.send 'END LOG'
		res.send '#############################################################'
