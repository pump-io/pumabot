# Description:
#   Says where the source is.
#
# Commands:
#   hubot where's the source? - replies with the URL for my source code

module.exports = (robot) ->

  robot.respond /(?:where's|where is) the source\??/i, (res) ->
    res.reply "https://github.com/strugee/hubot-pumpio"
