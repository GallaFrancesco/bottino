module bottino.bots.help;

import bottino.bots;
import bottino.irc;
import bottino.ircgrammar;

import vibe.core.log;

import std.algorithm.iteration;
import std.range;

/* ----------------------------------------------------------------------- */

// COMMAND = PREFIX ~ "help";

/* ----------------------------------------------------------------------- */

Bot createHelpBot(immutable string name,
                  immutable BotConfig config,
                  ref IrcClient irc) @safe
{
    return Bot(name, config, asBotAction!(helpWork!irc));
}

/* ----------------------------------------------------------------------- */

bool helpWork(alias IRC)(BotConfig config, string line) @safe nothrow
{
    auto cmd = IRCCommand(line);
    if(cmd.valid && cmd.command == COMMANDS["helpBot"]) {
        COMMANDS.byKey.each!((string name) {
                string dots;
                foreach(_; iota(0,16-COMMANDS[name].length)) dots ~= ".";
                string help = "PRIVMSG " ~ cmd.replyTarget(config.nick) ~ " :" ~
                    COMMANDS[name] ~
                    dots ~
                    COMMANDS.describe(name);
                IRC.sendRaw(help);
            });
    }
    return true;
}

/* ----------------------------------------------------------------------- */
