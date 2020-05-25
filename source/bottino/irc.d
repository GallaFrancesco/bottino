module bottino.irc;

import bottino.bots.common;

import vibe.core.log;
import vibe.core.net;
import vibe.stream.tls;
import vibe.core.task;
import vibe.core.core;
import vibe.stream.operations;
import sumtype;

import std.string;
import std.conv : to;
import std.algorithm.mutation;

/* ----------------------------------------------------------------------- */

IrcClient createIrcClient(immutable string server,
                          immutable ushort port,
                          immutable string password,
                          bool tls = false) @trusted
{
    IrcClient irc;

    if(tls) irc.proto = IrcTLS(server, port, password);
    else irc.proto = IrcTCP(server, port, password);

    return irc;
}

/* ----------------------------------------------------------------------- */

struct IrcClient
{
    _IrcClient proto;
    Bot[] bots;

    void connect(string nick, string realname) @safe
    {
        proto.match!(
                   (ref IrcTCP tcp) => tcp.connect(nick, realname),
                   (ref IrcTLS tls) => tls.connect(nick, realname));
    }

    void send(string cmd, string[] params ...) @safe
    {
        proto.match!(
                   (ref IrcTCP tcp) => tcp.send(cmd, params),
                   (ref IrcTLS tls) => tls.send(cmd, params));
    }

    string front() @safe
    {
        string text;
        proto.match!(
                   (ref IrcTCP tcp) => text = tcp.front(),
                   (ref IrcTLS tls) => text = tls.front());

        return text;
    }

    bool empty() @safe
    {
        return proto.match!(
                   (ref IrcTCP tcp) => tcp.empty(),
                   (ref IrcTLS tls) => tls.empty());
    }

    void registerBot(immutable string name, Bot bot) @safe
    {
        debug logInfo("[BOT] Registering bot: "~bot.name);
        bots ~= bot;
    }

    // handler for asynchronous server buffer processing
    void serveBots() @safe
    {
        while(!empty()) {
            string line = front();
            foreach(bot; bots) {
                bot.notify(line);
            }
        }
    }
}

/* ----------------------------------------------------------------------- */

private alias IrcTCP = Irc!TCPConnection;
private alias IrcTLS = Irc!TLSStream;
private alias _IrcClient = SumType!(IrcTCP,IrcTLS);

/* ----------------------------------------------------------------------- */

private struct Irc(ST)
{
    static assert(is(ST == TLSStream) || is(ST == TCPConnection),
                  "Irc accepts only TCP or TLS protocols");

    private {
        static if(is(ST == TLSStream)) {
            TCPConnection conn;
            TLSContext ctx;
        }
        ST stream;
    }

    string server;
    ushort port = 6667;
    string password = "";

    this(immutable string sv, immutable ushort p, immutable string pwd) @safe @nogc
    {
        server = sv;
        port = p;
        password = pwd;
    }

    // initialize TCP/TLS context and connect
    void connect(string nick, string realname) @safe
    {
        assert(!server.empty, "Cannot initialize IRC client without a server.");
        assert(!nick.empty, "Cannot connect to IRC server without a nick.");

        initialize();

        if(!password.empty) {
            send("PASS", password);
        }
        send("NICK", nick);
        if(!realname.startsWith(":")) {
            realname = ":" ~ realname;
        }
        send("USER", nick, "*", "*", realname);

        logInfo("Connected to " ~ server ~ " as: " ~ nick ~ realname);
    }


    // send a command to the server
    void send(string cmd, string[] params...)
    {
        assert(stream, "Cannot send on uninitialized stream");
        stream.write(command(cmd,params));
    }

    /* ------------------------------------------------------------- */
    /* Range-like IRC buffer interface                               */
    /* ------------------------------------------------------------- */

    string front() @trusted
    {
        assert(stream, "Cannot read from uninitialized stream");
        string buf;
        if(!empty) buf = cast(string)stream.readLine();
        return buf;
    }

    bool empty() @safe
    {
        assert(stream, "Cannot read from uninitialized stream");
        return stream.empty;
    }

    void popFront() @safe {} // bogus: front already pops

    /* ------------------------------------------------------------- */
    /* Utilities                                                     */
    /* ------------------------------------------------------------- */

    // initialize TCP or TLS connection
    private void initialize() @safe
    {
        static if(is(ST == TLSStream)) {
            conn = connectTCP(server, port);
            ctx = createTLSContext(TLSContextKind.client);
            ctx.peerValidationMode = TLSPeerValidationMode.checkTrust;
            stream = createTLSStream(conn, ctx);
        } else static if(is(ST == TCPConnection)) {
            stream = connectTCP(server, port);
        }

        assert(stream, "Unable to create stream.");
    }

    // build a IRC command
	private string command(string cmd, string[] params ...)
	{
		assert(cmd.length > 1);
		string message = toUpper(cmd);

		while ((params.length > 1) &&
               (params[$-1] == null || params[$-1] == "")) {
			params.length = params.length-1;
        }

		assert(params.length <= 15, "Too many arguments given to command()");

		foreach (i, parameter; params)
		{
			message ~= " ";
			if (parameter.indexOf(" ") != -1 || !parameter.length)
			{
				assert(i == params.length-1, "Malformed non-terminal parameter: " ~ parameter);
				message ~= ":";
			}
			message ~= parameter;
		}

        debug logInfo("[CMD] "~message);
        return message ~ "\n";
	}
}
