# Description:
#   Says where the source is.

module.exports = (robot) ->

  robot.respond /(?:where's|where is) the source\??/i, (res) ->
    res.send "https://github.com/strugee/hubot-pumpio"
