module bottino.bots.nickserv;

import bottino.bots : Bot, BotConfig, asBotAction, reply;
import bottino.irc;
import bottino.ircgrammar;

import pegged.grammar;
import d2sqlite3;
import vibe.core.log;
import vibe.core.file;

import std.digest.sha : sha512Of;
import std.algorithm.iteration;
import std.string;


/* ----------------------------------------------------------------------- */

// COMMAND = PREFIX ~ "echo";

/* ----------------------------------------------------------------------- */

immutable command = "auth";

Bot createNickServBot(immutable string name,
                      immutable BotConfig config,
                      ref IrcClient irc,
                      bool fromScratch = false) @trusted
{

    auto db = UserDB("./users.db", fromScratch);
    return Bot(name, command, "!auth (register|login) [nick] [password]", config, asBotAction!(nickservWork!(irc,db)));
}

/* ----------------------------------------------------------------------- */

bool nickservWork(alias IRC, alias DB)(BotConfig config, string line) @safe nothrow
{
    auto cmd = IRCCommand(line);
    if(cmd.valid && cmd.command == command && cmd.isPrivateQuery(config.nick)) {
        auto auth = AuthLine(cmd.text);
        if(auth.valid) {
            switch(auth.cmd) {
            case "register":
                DB.register(User(auth.nick, auth.password));
                cmd.reply!IRC("Benvenuto " ~ auth.nick ~", sappi che non c'e` modo di recuperare la password.", config);
                break;
            case "login":
                if(DB.isRegisteredUser(User(auth.nick, auth.password))) {
                    cmd.reply!IRC("di nuovo qui, "~auth.nick~"?", config);
                } else {
                    cmd.reply!IRC("nessuno ti conosce, "~auth.nick~"? Fatti due domande.", config);
                }
                break;
            default:
                cmd.reply!IRC("mammaaaa! "~auth.nick~" mi dice cose brutte!", config);
            }

        }
    }
    return true;
}


/* ----------------------------------------------------------------------- */

mixin(grammar(`
Auth:
   AuthMsg <- Cmd space* Nick space* Pwd
   Cmd     <- "register" / "login" 
   Nick    <- (!space !"!" Char)+
   Pwd     <- Char+
   Char    <- .
`));

struct AuthLine
{
    string cmd;
    string nick;
    string password;
    bool valid = false;

    this(immutable string line) @trusted nothrow
    {
        ParseTree pt;

        try {
            pt = IRCComm(line);
        } catch(Exception e) {
            import vibe.core.log;
            logWarn(e.msg);
            valid = false;
            return;
        }

        valid = pt.successful;

        if(!valid) return;

        traverse(pt);
        assert(!cmd.empty && !nick.empty && !password.empty,
               "Something went wrong with command AST traversal");
    }

    private void traverse(PT)(const ref PT pt) @trusted nothrow
    {
        switch(pt.name) {
        case "Auth.Cmd":
            cmd = pt.input[pt.begin..pt.end];
            break;
        case "Auth.Nick":
            nick = pt.input[pt.begin..pt.end];
            break;
        case "Auth.Pwd":
            password = pt.input[pt.begin..pt.end];
            break;
        default:
            break;
        }

        pt.children.each!((const ref PT p) => traverse(p));
    }

}


/* ----------------------------------------------------------------------- */
/* DB management                                                           */
/* ----------------------------------------------------------------------- */

struct User
{
    string nick;
    string password;

    this(immutable string n, immutable string clearPwd) @trusted nothrow
    {
        nick = nick;
        password = cast(string)sha512Of(clearPwd);
    }
}

struct UserDB
{
    private {
        Database db;
        immutable string location;
        Statement insert;
        Statement select;
    }

    this(immutable string loc, immutable bool fromScratch = false) @trusted nothrow
    {
        try {
            location = loc;
            auto init = false;
            if(!existsFile(location)) init = true;

            db = Database(location);

            if(fromScratch || init) {
                db.run("DROP TABLE IF EXISTS users;
                    CREATE TABLE users (
                    id    INTEGER PRIMARY KEY,
                    nick  TEXT NOT NULL,
                    password TEXT NOT NULL
                )");
            }

            insert = db.prepare(
                    "INSERT INTO users (nick, password)
                        VALUES (:nick, :password)"
                    );

            select = db.prepare(
                    "SELECT count(*) FROM users
                        WHERE nick == :nick
                        AND password == :password"
                    );
        } catch (Exception e) {
            assert(false, e.msg);
        }
    }

    void register(immutable User user) @trusted nothrow
    {
        try {
            insert.bind(":nick", user.nick);
            insert.bind(":password", user.password);
            insert.execute();
            insert.reset();
        } catch (Exception e) {
            assert(false, e.msg);
        }
    }

    bool isRegisteredUser(immutable User user) @trusted nothrow
    {
        try {
            select.bind(":nick", user.nick);
            select.bind(":password", user.password);
            auto res = select.execute().oneValue!bool;
            select.reset();
            return res;
        } catch (Exception e) {
            return false;
        }
    }
}
