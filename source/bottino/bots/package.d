module bottino.bots;
public import bottino.bots.logger;
public import bottino.bots.echo;
public import bottino.bots.help;
import bottino.ircgrammar;

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

BotCommands COMMANDS;

static this()
{
    COMMANDS["echoBot"] = ["echo", "Always in agreement with you"];
    COMMANDS["stopBot"] = ["stop", "You can(not) stop me"];
    COMMANDS["helpBot"] = ["help", "This help"];
}

struct BotCommands
{
    private string[string] commands;
    private string[string] descriptions;

    void opIndexAssign(string[] valDesc, string key) @safe nothrow
    {
        assert(valDesc.length == 2, "Invalid command description");

        string val = valDesc[0];
        assert(val.length < 16,
               "Command must be less than 16 characters long.");
        if(val.startsWith(PREFIX)) commands[key] = val;
        else commands[key] = PREFIX ~ val;

        descriptions[key] = valDesc[1];
    }

    string opIndex(string key) @safe nothrow
    {
        if(key in commands)
            return commands[key];
        else
            return PREFIX ~ "not_a_command";
    }

    string describe(string key) @safe nothrow
    {
        if(key in commands && key in descriptions)
            return descriptions[key];
        else
            return PREFIX ~ "not_a_command";
    }

    auto byKey() @safe
    {
        return commands.byKey.array;
    }

    auto byValue() @safe
    {
        return commands.byValue.array;
    }
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

                    if(IRCCommand(line).command == COMMANDS["stopBot"]) {
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
            });
    }

}

/* ----------------------------------------------------------------------- */

private enum BotState {
                       AWAKE,
                       ASLEEP,
                       DEAD
}

/* ----------------------------------------------------------------------- */
