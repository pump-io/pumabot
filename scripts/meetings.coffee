# Description:
#   Helps to run the monthly meeting.
#
# Commands:
#   hubot start meeting - announces the meeting start and the beginning of logging, and starts roll call
#   hubot meeting agenda - gives a reminder of the meeting agenda URL
#   hubot reload agenda - reloads the agenda of the active meeting
#   hubot current agenda item - prints the current agenda topic
#   hubot next agenda item - changes the current topic to the next item on the agenda
#   hubot previous agenda item - changes the current topic to the previous item on the agenda
#   hubot end meeting - thanks participants for coming and announces the end of the log

fs = require 'fs'
path = require 'path'
cloneOrPull = require 'git-clone-or-pull'
remark = require 'remark'
mdastToString = require 'mdast-util-to-string'
processor = remark()

agendaData = []
currentMeeting = null

formatAgendaItem = (item, depth=0) ->
	if depth is 0
		str = 'TOPIC: ' + item[0]
		str += formatAgendaItem item[1], 1
		return str

	if typeof item is 'string'
		str = '\n'
		str += Array(depth - 1).join '  '
		str += '* '
		str += item
		return str

	str = ''
	for i in item
		if typeof i is 'string'
			str += formatAgendaItem i, depth
		else
			str += formatAgendaItem i, (depth + 1)

	return str

handleListItem = (item) ->
	results = []
	for child in item.children
		switch child.type
			when 'paragraph' then results.push mdastToString(child)
			when 'list'
				for i in child.children
					results = results.concat handleListItem i
			else throw new Error('Weird agenda')

	results

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
			if node.type isnt 'list'
				continue

			for item in node.children
				data = handleListItem(item)
				if typeof data is 'string'
					agendaData.push data
				else if typeof data is 'array'
					agendaData = agendaData.concat data

		next()

processor.use extractAgenda

updateWiki = (callback) ->
	cloneOrPull 'https://github.com/e14n/pump.io.wiki.git', '/var/cache/hubot-pumpio/pump.io.wiki', (err) ->
		callback err or null

meetingLabel = (date) ->
	year = date.getFullYear().toString()
	month = date.getMonth() + 1
	month = if month < 10 then '0' + month.toString() else month.toString()
	day = date.getDate()
	day = if day < 10 then '0' + day.toString() else day.toString()
	str = 'Meeting-'
	str += year
	str += '-'
	str += month
	str += '-'
	str += day

class Meeting
	constructor: (@label, callback) ->
		@url = 'https://github.com/e14n/pump.io/wiki/' + @label
		@filename = path.join '/var/cache/hubot-pumpio/pump.io.wiki/', @label + '.md'
		@agenda = null
		@agendaTopic = 0
		@loadAgenda callback

	loadAgenda: (callback) ->
		filename = @filename
		updateWiki () =>
			fs.readFile filename, (err, data) =>
				if err then throw err

				doc = processor.process(data)

				@agenda = agendaData

				callback()

module.exports = (robot) ->
	updateWiki () ->
		# Do nothing

	robot.respond /start meeting/i, (res) ->
		if currentMeeting
			res.reply 'There\'s already a meeting in progress.'
			return

		res.reply res.random ['just a sec', 'no problem', 'sure']
		currentMeeting = new Meeting meetingLabel(new Date()), () ->
			robot.logger.info 'Started meeting: ' + currentMeeting.label
			# TODO: ping all
			res.send '#############################################################'
			res.send 'BEGIN LOG'
			res.send '#############################################################'
			res.send 'Welcome to this month\'s Pump.io community meeting! Everyone is welcome to participate.'
			res.send 'This meeting is being logged and it will be posted on the wiki at ' + currentMeeting.url + '. If you would like your nick redacted, please say so, either now or after the meeting.'
			res.send 'Let\'s start with roll call - who\'s here?'
			res.emote 'is here'

	robot.respond /meeting agenda/i, (res) ->
		if not currentMeeting
			res.reply 'There isn\'t currently a meeting going on.'
			return

		res.reply 'The agenda is at ' + currentMeeting.url + '#agenda.'

	robot.respond /reload agenda/i, (res) ->
		if not currentMeeting
			res.reply 'There isn\'t a meeting right now, so there\'s no agenda to reload.'
			return

		currentMeeting.loadAgenda () ->
			res.reply res.random ['just did', 'done', 'agenda reloaded.']

	robot.respond /current agenda item/i, (res) ->
		if not currentMeeting
			res.reply 'There isn\'t a meeting right now, so there\'s no agenda.'
			return

		res.send formatAgendaItem(currentMeeting.agenda[currentMeeting.agendaTopic])

	robot.respond /next agenda item/i, (res) ->
		if not currentMeeting
			res.reply 'There isn\'t a meeting right now, so there\'s no agenda.'
			return

		if currentMeeting.agendaTopic is currentMeeting.agenda.length - 1
			res.reply 'That\'s the last agenda item.'
			return

		currentMeeting.agendaTopic++
		res.send formatAgendaItem(currentMeeting.agenda[currentMeeting.agendaTopic])

	robot.respond /previous agenda item/i, (res) ->
		if not currentMeeting
			res.reply 'There isn\'t a meeting right now, so there\'s no agenda.'
			return

		if currentMeeting.agendaTopic is 0
			res.reply 'We\'re on the first agenda item.'
			return

		currentMeeting.agendaTopic--
		res.sendm formatAgendaItem(currentMeeting.agenda[currentMeeting.agendaTopic])

	robot.respond /end meeting/i, (res) ->
		if not currentMeeting
			res.reply 'There\'s no meeting to end.'
			return

		res.send 'Thank you all for attending! Logs will be posted on the wiki shortly at ' + currentMeeting.url + '.'
		res.send 'See you next month!'
		res.send '#############################################################'
		res.send 'END LOG'
		res.send '#############################################################'
		currentMeeting = null
