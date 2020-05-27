module bottino.bots.nickserv;

import bottino.bots;
import bottino.irc;
import bottino.ircgrammar;

import d2sqlite3;
import vibe.core.log;

/* ----------------------------------------------------------------------- */

// COMMAND = PREFIX ~ "echo";

/* ----------------------------------------------------------------------- */

immutable command = "auth";

Bot createNickServBot(immutable string name,
                      immutable BotConfig config,
                      ref IrcClient irc) @safe
{
    return Bot(name, command, "spiega commando auth", config, asBotAction!(nickservWork!irc));
}

/* ----------------------------------------------------------------------- */

bool nickservWork(alias IRC)(BotConfig config, string line) @safe nothrow
{
    auto cmd = IRCCommand(line);
    if(cmd.valid && cmd.command == command) {
        try {
            import std.stdio;
            writeln(cmd.replyTarget(config.nick));
        } catch(Exception e) {}
        string echo = "PRIVMSG " ~ cmd.replyTarget(config.nick) ~ " :" ~
            cmd.text;
        IRC.sendRaw(echo);
    }
    return true;
}

/* ----------------------------------------------------------------------- */
