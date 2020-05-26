module bottino.main;
import bottino.irc;
import bottino.bots;

import vibe.core.net;
import vibe.core.log;
import vibe.core.task;
import vibe.core.core;
import vibe.core.concurrency;
import vibe.stream.tls;
import sumtype;

import std.stdio;
import std.string;
import std.getopt;

export immutable string PREFIX = "!";

void main(string[] args)
{
    bool tls = false;
    string server;
    string password = "";
    ushort port = 6667;
    string nick;
    string realname;
    string[] channels;

    auto helpInformation = getopt(
                                  args,
                                  "server|s", "Server address", &server,
                                  "port|p", "Server port [6667]", &port,
                                  "password|k", "Server password [empty]", &password,
                                  "tls|t", "Use TLS (requires a SSL provider)", &tls,
                                  "nick|n", "Bot nick", &nick,
                                  "realname|r", "Bot realname [bottino]", &realname,
                                  "channel|c", "Add a channel (might be specified more than once)", &channels);

    if(helpInformation.helpWanted) {
        defaultGetoptPrinter("Bottino: IRC bot",
                             helpInformation.options);
        return;
    }

    immutable config = BotConfig(nick, realname, channels);

    // initialize IRC client & connect to server
    IrcClient irc = createIrcClient(server, port, password, tls);
    irc.connect(config.nick, config.realname);

    auto loggerBot = createLoggerBot("loggerino", config, "./logs");
    auto echoBot = createEchoBot("echoerino", config, irc);
    auto helpBot = createHelpBot("helperino", config, irc);
    irc.registerBot(echoBot.name, echoBot);
    irc.registerBot(loggerBot.name, loggerBot);
    irc.registerBot(helpBot.name, helpBot);

    irc.serveBots();

    logInfo("CIAO UAGNU'! Bottino is going down.");
}
