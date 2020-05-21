module bottino.main;

import ae.net.asockets;
import ae.net.irc.client;


import std.algorithm.iteration;
import std.string;
import std.getopt;

struct BotConfig {
public:
    string server;
    ushort port = 6667;
    string nick;
    string realname = "bottino";
    string[] channels;

    void addChannel(immutable string ch) @safe 
    {
        assert(!ch.empty, "Empty channel name provided.");

        if (ch.startsWith("#")) channels ~= '#' ~ ch;
        else channels ~= ch;
    }
}

/**
 * Connect to configured server
 */
void botConnect(TcpConnection tcp, IrcClient irc, immutable BotConfig config)
{
    irc.nickname = config.nick;
    irc.realname = config.realname;
    tcp.connect(config.server, config.port);

    config.channels.each!((channel) => irc.join(channel));
}

void main(string[] args)
{
    TcpConnection tcp;
    IrcClient irc;
    BotConfig config;
    string[] chs;

    auto helpInformation = getopt(
            args,
            "server|s", "Server address", &config.server,
            "port|p", "Server port [6667]", &config.port,
            "nick|n", "Bot nick", &config.nick,
            "realname|r", "Bot realname [bottino]", &config.realname,
            "channel|c", "Add a channel (might be specified more than once)", &config.channels);

    if(helpInformation.helpWanted) {
        defaultGetoptPrinter("Bottino: IRC bot",
                             helpInformation.options);
        return;
    }
}
