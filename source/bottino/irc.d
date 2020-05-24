module bottino.irc;

import vibe.core.log;
import vibe.core.net;
import vibe.stream.tls;
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
    _IrcClient proto;

    if(tls) proto = IrcTLS(server, port, password);
    else proto = IrcTCP(server, port, password);

    move(proto, irc.proto);
    return irc;
}

/* ----------------------------------------------------------------------- */

/**
 * Wrapper around a IRC!proto connection
 */
struct IrcClient {
    _IrcClient proto;

    void connect(string nick, string realname) @safe
    {
        proto.match!(
                   (IrcTCP tcp) => tcp.connect(nick, realname),
                   (IrcTLS tls) => tls.connect(nick, realname));
    }

    void send(string cmd, string[] params ...) @safe
    {
        proto.match!(
                   (IrcTCP tcp) => tcp.send(cmd, params),
                   (IrcTLS tls) => tls.send(cmd, params));
    }

    string readText() @safe
    {
        string text;
        proto.match!(
                   (IrcTCP tcp) => text = tcp.readText(),
                   (IrcTLS tls) => text = tls.readText());

        debug {
            logWarn(text);
        }
        return text;
    }
}

/* ----------------------------------------------------------------------- */

alias IrcTCP = Irc!TCPConnection;
alias IrcTLS = Irc!TLSStream;
alias _IrcClient = SumType!(IrcTCP,IrcTLS);

/* ----------------------------------------------------------------------- */

struct Irc(ST)
{
    private {
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

    void connect(string nick, string realname) @safe
    {
        assert(!server.empty, "Cannot initialize IRC client without a server.");
        assert(!nick.empty, "Cannot connect to IRC server without a nick.");

        initialize();

        if(!password.empty) {
            send("PASS", password);
        }

        send("NICK", nick);
        if(!realname.startsWith(":"))
            realname = ":" ~ realname;
        send("USER", nick, "*", "*", realname);

        debug logWarn(readText());

        logInfo("Connected to " ~ server ~ " as: " ~ nick ~ realname);
    }

    void send(string cmd, string[] params...)
    {
        assert(stream, "Cannot send on uninitialized stream");
        stream.write(command(cmd,params));
    }

    string readText() @trusted
    {
        assert(stream, "Cannot read from uninitialized stream");
        while(!stream.empty) {
            auto b = stream.readLine();
            logInfo(cast(string)b);
            // TODO process command here...
            buf ~= b;
            debug logWarn(to!string(stream.empty));
        }
        return cast(string)buf;
    }

    // initialize TCP or TLS connection
    private void initialize() @safe
    {
        static if(is(ST == TLSStream)) {
            auto conn = connectTCP(server, port);
            auto sslctx = createTLSContext(TLSContextKind.client);
            sslctx.peerValidationMode = TLSPeerValidationMode.checkTrust;
            stream = createTLSStream(conn, sslctx);
            assert(stream, "Unable to create stream.");
        } else static if(is(ST == TCPConnection)) {
            stream = connectTCP(server, port);
        }
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
