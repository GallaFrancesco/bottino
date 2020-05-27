module bottino.bots;
import bottino.ircgrammar;
import bottino.irc;

import vibe.core.core;
import vibe.core.concurrency : send, receiveOnly;
import vibe.core.task;
import vibe.core.log;

import std.string;
import std.container;
import std.algorithm.iteration;
import std.range;
import std.meta;
import std.conv : to;

/* ----------------------------------------------------------------------- */
/* Handle registered bot commands                                          */
/* ----------------------------------------------------------------------- */

Bot[] makeBots(ref IrcClient irc, const BotConfig config)
{
    import bottino.bots.logger;
    import bottino.bots.echo;
    import bottino.bots.raver;
    import bottino.bots.nickserv;
    import bottino.bots.help;

    Bot[] bots;

    bots ~= createEchoBot("echoerino", config, irc);
    bots ~= createRaverBot("raverino", config, irc);
    // bots ~= createNickServBot("nickerino", config, irc);
    bots ~= createHelpBot("helperino", config, bots, irc);
    // bots ~= createLoggerBot("loggerino", config, "./logs");

    return bots;
}
/* ----------------------------------------------------------------------- */
/* Actions are the work done by a bot on every line                        */
/* ----------------------------------------------------------------------- */

alias BotAction = bool delegate(BotConfig, immutable(string)) @safe nothrow;

/* ----------------------------------------------------------------------- */

auto asBotAction(alias funct)() @trusted
{
    import std.functional : toDelegate;
    BotAction dg = toDelegate(&funct);
    return dg;
}

/* ----------------------------------------------------------------------- */
/* The Bot                                                                 */
/* ----------------------------------------------------------------------- */

struct BotConfig
{
    immutable string nick;
    immutable string realname;
    immutable(string)[] channels;

    this(string n, string r, string[] chs) @safe
    {
        nick = n;
        realname = r;
        addChannels(chs);
    }

    void addChannels(string[] chs) @trusted
    {
        import vibe.core.concurrency;
        auto i_chs = makeIsolatedArray!string(chs.length);

        import std.stdio;
        foreach(ch; chs) {
            assert(!ch.empty, "Empty channel name provided.");

            if (!ch.startsWith("#")) i_chs ~= '#' ~ ch;
            else i_chs ~= ch;
        }

        channels = i_chs.freeze();
    }
}

/* ----------------------------------------------------------------------- */

struct Bot
{
    private {
        Task tid;
        BotState state = BotState.ASLEEP;
    }

    immutable string name;
    immutable string command;
    immutable string helpText;
    immutable BotConfig config;
    BotAction work;

    this(immutable string n, immutable string cmd, immutable string help, BotConfig c, BotAction act) @safe
    {
        name = n;
        helpText = help;
        command = cmd;
        config = c;
        work = act;
    }

    void notify(immutable string line) @trusted
    {
        if(state == BotState.DEAD) {
            debug logWarn("[BOT: "~name~"] Cannot notify dead bot."
                    ~"Something bad happened");
            return;
        }

        if(state == BotState.ASLEEP) wakeup();
        tid.send(line);
        yield();
    }

    void wakeup() @safe
    {
        final switch(state) {

        case BotState.ASLEEP:
            debug logInfo("[BOT: "~name~"] Waking up");
            state = BotState.AWAKE;
            workAsync();
            break;

        case BotState.DEAD:
            debug logWarn("[BOT: "~name~"] Is dead, something bad happened");
            break;

        case BotState.AWAKE:
            assert(false, "[BOT: "~name~" is already awake, "
                   ~"don't mess with its work");

        }
    }

    // polite: wait for finish then sleep
    void sleep() @safe
    {
        final switch(state) {

        case BotState.ASLEEP:
            assert(false, "[BOT: "~name~" is already sleeping, "
                   ~"don't mess with its sleep");

        case BotState.DEAD:
            debug logWarn("[BOT: "~name~"] Is dead, something bad happened");
            break;

        case BotState.AWAKE:
            debug logInfo("[BOT: "~name~"] Going to sleep");
            state = BotState.ASLEEP;
            break;
        }
    }

    void kill() @safe
    {
        debug logWarn("[BOT: "~name~"] Just got killed, something bad happened");
        state = BotState.DEAD;
    }

    // asynchronous interface to handle multiple bots
    private void workAsync() @safe
    {
        tid = runTask(() @trusted {

                while(state == BotState.AWAKE) {
                    auto line = receiveOnly!string();

                    /// not working
                    // if(IRCCommand(line).command == COMMANDS["stopBot"]) {
                    //     logInfo("[BOT "~name~"] Going to sleep");
                    //     sleep();
                    //     break;
                    // }

                    bool ok = work(config, line);
                    if(!ok) {
                        kill();
                        break;
                    }
                }
            });
    }

}

/* ----------------------------------------------------------------------- */

private enum BotState
{
 AWAKE,
 ASLEEP,
 DEAD
}

/* ----------------------------------------------------------------------- */

void print(T...) (T args) @safe nothrow
{
    debug{
        import std.stdio: writeln;
        try{
            writeln(args);
        }catch(Exception e){} // hope it never blows up
    }
}

/* ----------------------------------------------------------------------- */

void privateReply(alias IRC)(IRCCommand cmd, immutable string msg) @safe nothrow
{
    string irc_msg = "PRIVMSG "~cmd.sender~" :"~msg;
    IRC.sendRaw(irc_msg);
}

/* ----------------------------------------------------------------------- */

void reply(alias IRC)(IRCCommand cmd, immutable string msg, const BotConfig config) @safe nothrow
{
    string irc_msg = "PRIVMSG "~cmd.replyTarget(config.nick)~" :"~msg;
    IRC.sendRaw(irc_msg);
}

/* ----------------------------------------------------------------------- */
