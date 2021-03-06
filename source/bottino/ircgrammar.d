module bottino.ircgrammar;

import pegged.grammar;

import std.string;
import std.array;
import std.ascii;
import std.algorithm.iteration;

immutable string PREFIX = "!";

/* ------------------------------------------------------------- */
/* IRC reply line                                                */
/* ------------------------------------------------------------- */
mixin(grammar(`
IRCReply:
   Line     <~ Prefix space* Code space* Message
   Prefix   <~ ":" (!space Char)*
   Code     <~ [0-9]+
   Message  <~ (space / Char)*
   Char     <~ .
`));

// for now we only need to know if a line is a reply or not
bool isReply(immutable string line) @trusted nothrow
{
    try {
        return IRCReply(line).successful;
    } catch (Exception e) {
        return false;
    }
}

/* ------------------------------------------------------------- */
/* IRC command line                                              */
/* ------------------------------------------------------------- */

mixin(grammar(`
IRCComm:
   Line     <- Prefix space* MsgType space* ^Target space* Message
   Prefix   <- ":" ^Sender "!" (!space Char)*
   Target   <- ("#" Ident) / Ident
   MsgType  <- "PRIVMSG"
   Message  <- ":" ^Command (space ^Text)*
   Sender   <- Ident
   Command  <- "`~PREFIX~`" identifier
   Text     <- (space / Char)*
   Ident    <- (!space !"!" Char)+
   Char     <- .
`));

// built by parsing through IRCComm
struct IRCCommand
{
    struct BotCommand {
        string cmd;
        alias cmd this;
        /// Implement equality but consider that the user may forgot to put a "!" in front of bot.command
        bool opEquals(const string lf) pure @safe nothrow {
            return lf == cmd || (cmd.startsWith("!") && cmd[1..$] == lf);
        }
    }
    
    string sender;
    string target;
    BotCommand command;
    string text;
    bool valid;

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
        assert(!target.empty && !command.empty,
               "Something went wrong with command AST traversal");
    }

    private void traverse(PT)(const ref PT pt) @safe nothrow
    {
        switch(pt.name) {
        case "IRCComm.Sender":
            sender = pt.input[pt.begin..pt.end];
            break;
        case "IRCComm.Target":
            target = pt.input[pt.begin..pt.end];
            break;
        case "IRCComm.Command":
            command = pt.input[pt.begin..pt.end];
            break;
        case "IRCComm.Text":
            text = pt.input[pt.begin..pt.end];
            break;
        default:
            break;
        }

        pt.children.each!((const ref PT p) => traverse(p));
    }

    bool isPrivateQuery(immutable string nick) @safe nothrow
    {
        return target == nick;
    }

    string replyTarget(immutable string nick) @safe nothrow
    {
        return isPrivateQuery(nick) ? sender : target;
    }
}


/* ------------------------------------------------------------- */
/* IRC PING                                                      */
/* ------------------------------------------------------------- */

mixin(grammar(`
IRCPing:
   Line     <- "PING" space* Message
   Message  <- (space / Char)*
   Char     <- .
`));

// for now we only need to know if a line is a reply or not
string tryPong(immutable string line) @trusted nothrow
{
    void traverse(PT)(const ref PT pt, ref string pong) @safe nothrow
    {
        if(pt.name == "IRCPing.Message") {
            pong = "PONG :"~pt.matches.join();
            return;
        }
        
        else pt.children.each!((const ref PT p) => traverse(p,pong));
    }

    ParseTree pt;
    string pong;
    try {
        pt = IRCPing(line);
    } catch (Exception e) {
        import vibe.core.log;
        logWarn(e.msg);
        return "";
    }


    if(!pt.successful) return "";
    traverse(pt,pong);
    return pong;
}

/* ------------------------------------------------------------- */
/* IRC Invite                                                    */
/* ------------------------------------------------------------- */

mixin(grammar(`
IRCInv:
   Line     <- Prefix space* "INVITE" space* ^Target space* ^Channel
   Prefix   <- ":" ^Sender "!" (!space Char)*
   Target   <- Ident
   Channel  <- ("#" Ident)
   Sender   <- Ident
   Ident    <- (!space !"!" Char)+
   Char     <- .
`));

// built by parsing through IRCComm
struct IRCInvite
{
    string sender;
    string target;
    string channel;
    bool valid;

    this(immutable string line) @trusted nothrow
    {
        ParseTree pt;

        try {
            pt = IRCInv(line);
        } catch(Exception e) {
            import vibe.core.log;
            logWarn(e.msg);
            valid = false;
            return;
        }

        valid = pt.successful;

        if(!valid) return;

        traverse(pt);
        assert(!target.empty && !channel.empty,
               "Something went wrong with invite AST traversal");
    }

    private void traverse(PT)(const ref PT pt) @safe nothrow
    {
        switch(pt.name) {
        case "IRCInv.Sender":
            sender = pt.input[pt.begin..pt.end];
            break;
        case "IRCInv.Target":
            target = pt.input[pt.begin..pt.end];
            break;
        case "IRCInv.Channel":
            channel = pt.input[pt.begin..pt.end];
            break;
        default:
            break;
        }

        pt.children.each!((const ref PT p) => traverse(p));
    }
}
