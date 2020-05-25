module bottino.bots.echo;

import bottino.bots.common;
import bottino.irc;
import bottino.ircgrammar;

import vibe.core.log;
debug import std.stdio;

/* ----------------------------------------------------------------------- */

Bot createEchoBot(immutable string name,
                  immutable BotConfig config,
                  ref IrcClient irc) @safe
{
    return Bot(name, config, asBotAction!(echoWork!irc));
}

/* ----------------------------------------------------------------------- */

bool echoWork(alias IRC)(BotConfig config, string line) @safe nothrow
{
    if(ircg_isPrivMsg(line)) {
        IRC.sendRaw(ircg_noPrefix(line));
    }
    return true;
}

/* ----------------------------------------------------------------------- */
