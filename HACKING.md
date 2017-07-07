# Development

## Running pumabot Locally

You can start pumabot locally by running:

    % eval "$(sed 's/^/export /g' hubot.environment)"
    % bin/hubot

(The first command sets up the environment based on `hubot.environment`.)

You'll see some start up output and a prompt:

    [Sat Feb 28 2015 12:38:27 GMT+0000 (GMT)] INFO Using default redis on localhost:6379
    pumabot>

Then you can interact with pumabot by typing `pumabot help`.

    pumabot> pumabot help
    pumabot animate me <query> - The same thing as `image me`, except adds [snip]
    pumabot help - Displays all of the help commands that pumabot knows about.
    ...

pumabot uses `hubot-redis-brain` for persistence. [AJ][] runs a Redis in
production for this, but you'll probably want to set one up for dev environments
too.

[AJ]: https://strugee.net

## Configuration

Some scripts require environment variables to be set as a simple form
of configuration.

Each script should have a commented header which contains a "Configuration"
section that explains which values it requires to be placed in which variable.
When you have lots of scripts installed this process can be quite labour
intensive. The following shell command can be used as a stop gap until an
easier way to do this has been implemented.

    grep -o 'hubot-[a-z0-9_-]\+' external-scripts.json | \
      xargs -n1 -I {} sh -c 'sed -n "/^# Configuration/,/^#$/ s/^/{} /p" \
          $(find node_modules/{}/ -name "*.coffee")' | \
        awk -F '#' '{ printf "%-25s %s\n", $1, $2 }'

If you need to specify an environment variable, you can add it to
`hubot.environment` and it will automatically be picked up in
production. The only variable that's missing from that file, aside
from operations-related values (and secrets), is
`HUBOT_ANSWER_TO_THE_ULTIMATE_QUESTION_OF_LIFE_THE_UNIVERSE_AND_EVERYTHING`.

## Extending

You can write custom scripts and put them in `scripts/` - check out
what's there to get a feel for what you can do (especially
`example.coffee`). You might also find
the [Scripting Guide](scripting-docs) useful.

You can also pull in functionality from npm modules - this is
generally preferred. You can get a list of available hubot plugins
on [npmjs.com][npmjs] or by using `npm search`:

    % npm search hubot-scripts panda
    NAME             DESCRIPTION                        AUTHOR DATE       VERSION KEYWORDS
    hubot-pandapanda a hubot script for panda responses =missu 2014-11-30 0.9.2   hubot hubot-scripts panda
    ...


To use a package, check the package's documentation, but in general it is:

1. Use `npm install --save` to add the package to `package.json` and install it
2. Add the package name to `external-scripts.json` as a double quoted string

[npmjs]: https://www.npmjs.com
[scripting-docs]: https://github.com/github/hubot/blob/master/docs/scripting.md

### Advanced Usage

It is also possible to define `external-scripts.json` as an object to
explicitly specify which scripts from a package should be included. The example
below, for example, will only activate two of the six available scripts inside
the `hubot-fun` plugin, but all four of those in `hubot-auto-deploy`.

```json
{
  "hubot-fun": [
    "crazy",
    "thanks"
  ],
  "hubot-auto-deploy": "*"
}
```

**Be aware that not all plugins support this usage and will typically fallback
to including all scripts.**
