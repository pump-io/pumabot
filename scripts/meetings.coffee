# Description:
#   Helps to run the monthly meeting.
#
# Commands:
#   hubot start meeting - announces the meeting start and the beginning of logging, and starts roll call
#   hubot meeting agenda - gives a reminder of the meeting agenda URL
#   hubot who's chairing? - says who is chairing the current meeting
#   hubot <nick> is chairing - sets a new chair for the current meeting
#   hubot reload agenda - reloads the agenda of the active meeting
#   hubot current agenda item - prints the current agenda topic
#   hubot next agenda item - changes the current topic to the next item on the agenda
#   hubot previous agenda item - changes the current topic to the previous item on the agenda
#   hubot end meeting - thanks participants for coming and announces the end of the log

fs = require 'fs'
path = require 'path'
_ = require 'lodash'
cloneOrPull = require 'git-clone-or-pull'
remark = require 'remark'
mdastToString = require 'mdast-util-to-string'
processor = remark()

agendaData = []
currentMeeting = null

formatAgendaItem = (item, depth=0) ->
	if depth is 0
		str = 'TOPIC: ' + item[0]
		for i in item.slice 1 # Slice the first item out, as it was just printed
			str += formatAgendaItem i, (depth + 1)
		return str

	if typeof item is 'string'
		str = '\n'
		str += Array(depth - 1).join '	'
		str += '* '
		str += item
		return str
	else if _.isArray item
		# Sublist
		str = ''
		for i in item
			str += formatAgendaItem i, (depth + 1)
	else
		throw new Error 'Agenda data is totally screwed'

	return str

handleListItem = (item) ->
	# Returns an array of objects representing list items
	# Objects are either arrays representing (sub)lists or strings

	results = []
	for child in item.children
		switch child.type
			# If it's a paragraph, i.e. just text, we return the string
			when 'paragraph' then results.push mdastToString(child)
			# If it's a sublist, we return an array representing the sublist,
			# which is computed by a recursive call to handleListItem().
			when 'list'
				for sublistItem in child.children
					results.push handleListItem(sublistItem)
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

			for listItem in node.children
				agendaData.push handleListItem(listItem)

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
	constructor: (@label, @chair, callback) ->
		@url = 'https://github.com/e14n/pump.io/wiki/' + @label
		@filename = path.join '/var/cache/hubot-pumpio/pump.io.wiki/', @label + '.md'
		# undefined = not loaded, null = not available
		@agenda = undefined
		@agendaTopic = 0
		@loadAgenda callback

	loadAgenda: (callback) ->
		filename = @filename
		@agenda = undefined
		updateWiki (err) =>
			if err
				@agenda = null
				callback err
				return
			fs.readFile filename, (err, data) =>
				if err
					@agenda = null
					callback err
					return

				doc = processor.process(data)
				@agenda = agendaData

				callback()

agendaSanityCheck = (res) ->
	if not currentMeeting
		res.reply 'there isn\'t a meeting right now, so there\'s no agenda.'
		return false

	if currentMeeting.agenda is null
		res.reply 'sorry! For some reason, I don\'t have agenda data for this meeting.'
		return false

	if currentMeeting.agenda is undefined
		res.reply 'I\'m still loading data! Please be patient.'
		return false

	return true

module.exports = (robot) ->
	updateWiki (err) ->
		if err then throw err
		# Do nothing on success

	robot.respond /start meeting/i, (res) ->
		if currentMeeting
			res.reply 'there\'s already a meeting in progress.'
			return

		res.reply res.random ['just a sec', 'no problem', 'sure']
		res.reply 'I assume you\'re chairing the meeting?'
		res.send 'If not, tell me who is with  \'<nick> is chairing\''
		currentMeeting = new Meeting meetingLabel(new Date()), res.message.user.name, (err) ->
			robot.logger.info 'Started meeting: ' + currentMeeting.label

			if err then res.send 'I seem to have run into some trouble loading the agenda, so I won\'t be able to help you out during the meeting.'

			# TODO: ping all
			res.send '#############################################################'
			res.send 'BEGIN LOG'
			res.send '#############################################################'
			res.send 'Welcome to this month\'s Pump.io community meeting! Everyone is welcome to participate.'
			res.send 'This meeting is being logged and it will be posted on the wiki at ' + currentMeeting.url + '. If you would like your nick redacted, please say so, either now or after the meeting.'
			res.send 'Let\'s start with roll call - who\'s here?'
			res.emote 'is here'

	robot.respond /who's chairing\?/i, (res) ->
		if not currentMeeting
			res.reply 'there isn\'t currently a meeting going on.'
			return

		res.reply currentMeeting.chair + ' is chairing this meeting.'

	robot.respond /(.*) is(:? now)? chairing(:? this meeting)?/i, (res) ->
		if not currentMeeting
			res.reply 'there isn\'t currently a meeting going on.'
			return

		currentMeeting.chair = res.match[1]
		res.reply 'ok, ' + currentMeeting.chair + ' is now chairing this meeting.'

	robot.respond /meeting agenda/i, (res) ->
		if not currentMeeting
			res.reply 'there isn\'t currently a meeting going on.'
			return

		res.reply 'the agenda is at ' + currentMeeting.url + '#agenda.'

	robot.respond /reload agenda/i, (res) ->
		if not currentMeeting
			res.reply 'there isn\'t a meeting right now, so there\'s no agenda to reload.'
			return

		currentMeeting.loadAgenda (err) ->
			if err
				res.reply 'I got an error, sorry'
				return

			res.reply res.random ['just did', 'done', 'agenda reloaded.']

	robot.respond /current agenda item/i, (res) ->
		if not agendaSanityCheck res then return

		res.send formatAgendaItem(currentMeeting.agenda[currentMeeting.agendaTopic])

	robot.respond /next agenda item/i, (res) ->
		if not agendaSanityCheck res then return

		if currentMeeting.agendaTopic is currentMeeting.agenda.length - 1
			res.reply 'that\'s the last agenda item.'
			return

		currentMeeting.agendaTopic++
		res.send formatAgendaItem(currentMeeting.agenda[currentMeeting.agendaTopic])

	robot.respond /previous agenda item/i, (res) ->
		if not agendaSanityCheck res then return

		if currentMeeting.agendaTopic is 0
			res.reply 'we\'re on the first agenda item.'
			return

		currentMeeting.agendaTopic--
		res.send formatAgendaItem(currentMeeting.agenda[currentMeeting.agendaTopic])

	robot.respond /end meeting/i, (res) ->
		if not currentMeeting
			res.reply 'there\'s no meeting to end.'
			return

		res.send 'Thank you all for attending! Logs will be posted on the wiki shortly at ' + currentMeeting.url + '.'
		res.send 'Also, special thanks to ' + currentMeeting.chair + ' for chairing!'
		res.send 'See you next month!'
		res.send '#############################################################'
		res.send 'END LOG'
		res.send '#############################################################'
		currentMeeting = null
