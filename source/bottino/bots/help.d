module bottino.bots.help;

import bottino.bots;
import bottino.irc;
import bottino.ircgrammar;

import vibe.core.log;

import std.algorithm.iteration;
import std.range;

/* ----------------------------------------------------------------------- */

// COMMAND = PREFIX ~ "help";

/* ----------------------------------------------------------------------- */

immutable command = "help";

Bot createHelpBot(immutable string name,
                  immutable BotConfig config,
                  Bot[] bots,
                  ref IrcClient irc) @safe
{

    bool helpWork(alias IRC)(BotConfig config, string line) @safe nothrow
    {
        auto cmd = IRCCommand(line);
            if(cmd.valid && cmd.command == command) {
                BotCommands COMMANDS;
                // build commands struct
                foreach(bot; bots)
                    COMMANDS[bot.name] = [bot.command, bot.helpText] ;
        
                COMMANDS.byKey.each!((string name) {
                        string dots;
                        foreach(_; iota(0,16-COMMANDS[name].length)) dots ~= ".";
                        string help = "PRIVMSG " ~ cmd.replyTarget(config.nick) ~ " :" ~
                            COMMANDS[name] ~
                            dots ~
                            COMMANDS.describe(name);
                        IRC.sendRaw(help);
                    });
            }
        return true;
    }

/* ----------------------------------------------------------------------- */

    return Bot(name, command, "Aiutati che Dio ti aiuta", config, asBotAction!(helpWork!irc));
}

/* ----------------------------------------------------------------------- */


struct BotCommands
{
    import std.string;
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
