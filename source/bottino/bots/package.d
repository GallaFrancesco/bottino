module bottino.bots;
public import bottino.bots.logger;
public import bottino.bots.echo;

import bottino.ircgrammar;

import sumtype;

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

debug import std.stdio;

/* ----------------------------------------------------------------------- */

static immutable string PREFIX = "!";

// default accepted commands
static immutable string STOPPER = PREFIX ~ "stop";
static immutable string HELPER = PREFIX ~ "help";


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

// asynchronous interface to handle multiple bots
struct Bot
{
    private {
        Task tid;
        BotState state = BotState.ASLEEP;
    }

    immutable string name;
    immutable BotConfig config;
    BotAction work;

    this(immutable string n, BotConfig c, BotAction act) @safe
    {
        name = n;
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
            processTask();
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

    private void processTask() @safe
    {
        tid = runTask(&asyncProc);
    }

    private void asyncProc() @trusted
    {
        while(state == BotState.AWAKE) {
            auto line = receiveOnly!string();

            if(IRCCommand(line).command == STOPPER) {
                logInfo("[BOT "~name~"] Going to sleep");
                sleep();
                break;
            }

            bool ok = work(config, line);
            if(!ok) {
                kill();
                break;
            }
        }
    }

}

/* ----------------------------------------------------------------------- */

private enum BotState {
                       AWAKE,
                       ASLEEP,
                       DEAD
}

/* ----------------------------------------------------------------------- */
