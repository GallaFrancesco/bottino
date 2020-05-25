module bottino.bots.logger;

import bottino.bots;
import bottino.ircgrammar;

import vibe.core.file;
import vibe.core.path;
import vibe.core.log;

/* ----------------------------------------------------------------------- */

/* This bot does not accept commands.                                      */

/* ----------------------------------------------------------------------- */

Bot createLoggerBot(immutable string name,
                    immutable BotConfig config,
                    string lDir) @safe
{
    auto logDir = NativePath(lDir);
    if(!existsFile(logDir)) {
        createDirectory(logDir);
    }
    return Bot(name, config, asBotAction!(loggerWork!lDir)());
}

/* ----------------------------------------------------------------------- */

bool loggerWork(alias LOGDIR)(BotConfig config, string line) @safe nothrow
{
    logInfo(line);
    return true;
}

/* ----------------------------------------------------------------------- */
