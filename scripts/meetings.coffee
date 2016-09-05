# Description:
#   Helps to run the monthly meeting.
#
# Commands:
#   hubot start meeting - announces the meeting start and the beginning of logging, and starts roll call
#   hubot meeting agenda - gives a reminder of the meeting agenda URL
#   hubot end meeting - thanks participants for coming and announces the end of the log

fs = require 'fs'
path = require 'path'
cloneOrPull = require 'git-clone-or-pull'
remark = require 'remark'
mdastToString = require 'mdast-util-to-string'
processor = remark()

agendaData = ''

extractAgenda = () ->
	(ast, file, next) ->
		foundAgenda = false
		agendaNodes = []

		for node in ast.children
			if node.type is 'heading' and node.children[0].value is 'Agenda'
				# Agenda-related nodes are starting
				foundAgenda = true
			else if node.type is 'heading'
				# We've hit another heading, signaling the end of agenda-related nodes
				foundAgenda = false
			else if foundAgenda
				# Agenda-related node
				agendaNodes.push node

		for node in agendaNodes
			agendaData += mdastToString node

		next()

processor.use extractAgenda

updateWiki = (callback) ->
	cloneOrPull 'https://github.com/e14n/pump.io.wiki.git', '/var/lib/hubot-pumpio/pump.io.wiki', (err) ->
		callback err or null

meetingLabel = (date) ->
	year = date.getFullYear().toString()
	month = date.getMonth() + 1
	month = if month < 10 then '0' + month.toString() else month.toString()
	day = date.getDate()
	day = if day < 10 then '0' + day.toString() else day.toString()
	str = year
	str += '-'
	str += month
	str += '-'
	str += day

meetingPage = (date) ->
	'https://github.com/e14n/pump.io/wiki/Meeting-' + meetingLabel(date)

meetingFile = (date) ->
	path.join '/var/lib/hubot-pumpio/pump.io.wiki/', meetingLabel(date) + '.md'

meetingAgenda = (date, callback) ->
	fs.readFile meetingFile(date), (err, data) ->
		if err then throw err
		doc = processor.process(data)

		callback null

module.exports = (robot) ->
	updateWiki () ->
		# Do nothing

	robot.respond /start meeting/i, (res) ->
		res.reply res.random ['just a sec', 'no problem', 'sure']
		meetingAgenda new Date(), () ->
			# TODO: ping all
			res.send '#############################################################'
			res.send 'BEGIN LOG'
			res.send '#############################################################'
			res.send 'Welcome to this month\'s Pump.io community meeting! Everyone is welcome to participate.'
			res.send 'This meeting is being logged and it will be posted on the wiki at ' + meetingPage(new Date()) + '. If you would like your nick redacted, please say so, either now or after the meeting.'
			res.send 'Let\'s start with roll call - who\'s here?'
			res.emote 'is here'

	robot.respond /meeting agenda/i, (res) ->
		res.reply 'The agenda is at ' + meetingPage(new Date()) + '#agenda.'

	robot.respond /end meeting/i, (res) ->
		res.send 'Thank you all for attending! Logs will be posted on the wiki shortly at ' + meetingPage(new Date()) + '.'
		res.send 'See you next month!'
		res.send '#############################################################'
		res.send 'END LOG'
		res.send '#############################################################'
