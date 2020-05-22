module bottino.main;

import ae.net.asockets;
import ae.net.irc.client;
import ae.net.shutdown;
import ae.net.ssl;
import ae.net.ssl.openssl;
import ae.sys.log;
import ae.sys.timing;
import ae.utils.text;

import std.algorithm.iteration;
import std.string;
import std.getopt;
import std.typecons : No;

debug import std.stdio;

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

    inout bool initialized() @safe @nogc
    {
        return !server.empty && !nick.empty;
    }

}

private alias NoTLS = No;

/**
 * Connect to configured server
 */
void botConnect(Conn, TLS)(Conn conn, IrcClient irc, BotConfig config, TLS tls)
    if(is(TLS : SSLAdapter) || is(TLS == NoTLS))
{
    assert(config.initialized, "Cannot call botConnect with an empty config");

    irc.nickname = config.nick;
    irc.realname = config.realname;
    irc.encoder = irc.decoder = &nullStringTransform;
    irc.log = createLogger("IRC:"~config.server);
    conn.connect(config.server, config.port);

    debug {
        while(!irc.connected) {
            writeln("not connected?");
        }
    }

    // called upon successful connection
    irc.handleConnect = () { config.channels.each!((ch) => irc.join(ch)); };
}

void main(string[] args)
{
    BotConfig config;
    bool tls = false;

    auto helpInformation = getopt(
            args,
            "server|s", "Server address", &config.server,
            "port|p", "Server port [6667]", &config.port,
            "tls|t", "Use TLS (requires a SSL provider)", &tls,
            "nick|n", "Bot nick", &config.nick,
            "realname|r", "Bot realname [bottino]", &config.realname,
            "channel|c", "Add a channel (might be specified more than once)", &config.channels);

    if(helpInformation.helpWanted) {
        defaultGetoptPrinter("Bottino: IRC bot",
                             helpInformation.options);
        return;
    }

    TcpConnection tcp = new TcpConnection;
    IrcClient irc;

    if(tls) {
        debug writeln("Using TLS");
        auto ctx = ssl.createContext(OpenSSLContext.Kind.client);
        auto sslConn = ssl.createAdapter(ctx, tcp);
        irc = new IrcClient(sslConn);
        botConnect(tcp, irc, config, sslConn);
    } else {
        debug writeln("Not using TLS");
        irc = new IrcClient(tcp);
        botConnect(tcp, irc, config, NoTLS());
    }
}
