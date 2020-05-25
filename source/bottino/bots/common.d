module bottino.bots.common;

import sumtype;

import vibe.core.core;
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
        BotCache!string pipeline;
    }

    immutable string name;
    immutable BotConfig config;
    BotAction work;

    this(immutable string n, BotConfig c, BotAction act) @safe
    {
        name = n;
        config = c;
        work = act;
        pipeline = new BotCache!string();
    }

    void notify(immutable string line) @safe
    {
        if(state == BotState.DEAD) {
            debug logWarn("[BOT: "~name~"] Cannot notify dead bot."
                    ~"Something bad happened");
            return;
        }

        if(state == BotState.AWAKE) {
            sleep();
        }

        pipeline.insertBack(line);

        if(state == BotState.ASLEEP) { // wake up and start processing
            wakeup();
        }
    }

    void wakeup() @safe
    {
        final switch(state) {

        case BotState.ASLEEP:
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
            state = BotState.ASLEEP;
            tid.join();
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

    private void asyncProc() @safe
    {
        while(state == BotState.AWAKE) {
            bool ok = work(config, pipeline.front);
            if(!ok) {
                kill();
                break;
            }

            pipeline.popFront();

            if(pipeline.empty()) {
                sleep();
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

private class BotCache(T)
{
    private {
        immutable(T)[] cache;
    }

    bool empty() @safe
    {
        return cache.empty;
    }

    immutable(T) front() @safe
    {
        return cache.front;
    }

    void popFront() @safe
    {
        assert(!empty);
        cache.popFront();
    }

    void insertBack(immutable T item) @safe nothrow
    {
        cache ~= item;
    }
}
