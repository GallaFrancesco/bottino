module bottino.main;
import bottino.irc;

import vibe.core.net;
import vibe.stream.tls;
import sumtype;

import std.stdio;
import std.string;
import std.getopt;

struct BotConfig {
public:
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

void main(string[] args)
{
    BotConfig config;
    bool tls = false;
    string server;
    string password = "";
    ushort port = 6667;


    auto helpInformation = getopt(
                                  args,
                                  "server|s", "Server address", &server,
                                  "port|p", "Server port [6667]", &port,
                                  "password|k", "Server password [empty]", &password,
                                  "tls|t", "Use TLS (requires a SSL provider)", &tls,
                                  "nick|n", "Bot nick", &config.nick,
                                  "realname|r", "Bot realname [bottino]", &config.realname,
                                  "channel|c", "Add a channel (might be specified more than once)", &config.channels);

    if(helpInformation.helpWanted) {
        defaultGetoptPrinter("Bottino: IRC bot",
                             helpInformation.options);
        return;
    }

    // initialize IRC client & connect to server
    IrcClient irc = createIrcClient(server, port, password, tls);
    irc.connect(config.nick, config.realname);
    irc.send("JOIN", "#anabbot");
}
