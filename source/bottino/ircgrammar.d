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
   Prefix   <- ":" (!space Char)*
   Target   <- ("#" identifier) / identifier
   MsgType  <- "PRIVMSG"
   Message  <- ":" ^Command (space ^Text)*
   Command  <- "`~PREFIX~`" identifier
   Text     <- (space / Char)*
   Char     <- .
`));

// built by parsing through IRCComm
struct IRCCommand
{
    string target;
    string command;
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
