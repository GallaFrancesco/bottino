module bottino.bots.echo;

import bottino.bots;
import bottino.irc;
import bottino.ircgrammar;

import vibe.core.log;

/* ----------------------------------------------------------------------- */

// COMMAND = PREFIX ~ "echo";

/* ----------------------------------------------------------------------- */

immutable command = "echo";

Bot createEchoBot(immutable string name,
                  immutable BotConfig config,
                  ref IrcClient irc) @safe
{
    return Bot(name, command, "Always in agreement with you", config, asBotAction!(echoWork!irc));
}

/* ----------------------------------------------------------------------- */

bool echoWork(alias IRC)(BotConfig config, string line) @safe nothrow
{
    auto cmd = IRCCommand(line);
    if(cmd.valid && cmd.command == command) {
        string echo = "PRIVMSG "~cmd.replyTarget(config.nick)~" :"~cmd.text;
        IRC.sendRaw(echo);
    }
    return true;
}

/* ----------------------------------------------------------------------- */
