module bottino.bots.logger;

import bottino.bots.common;

import vibe.core.file;
import vibe.core.path;
import vibe.core.log;

debug import std.stdio;

/* ----------------------------------------------------------------------- */

Bot createLoggerBot(immutable string name,
                    immutable BotConfig config,
                    string lDir) @safe
{
    auto logDir = NativePath(lDir);
    if(!existsFile(logDir)) {
        createDirectory(logDir);
    }
    return Bot(name, config, asBotAction!loggerWork());
}

/* ----------------------------------------------------------------------- */

bool loggerWork(BotConfig config, string line) @safe nothrow
{
    debug logWarn("[LOGGER] "~line);
    return true;
}

/* ----------------------------------------------------------------------- */
