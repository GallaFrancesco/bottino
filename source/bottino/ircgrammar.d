module bottino.ircgrammar;

import pegged.grammar;

import std.string;
import std.array;
import std.ascii;

mixin(grammar(`
IRCReply:
   Line     <~ Prefix space* Code space* Message
   Prefix   <~ ":" (!space Char)*
   Code     <~ [0-9]+
   Message  <~ (space / Char)*
   Char     <~ .
`));

/* ------------------------------------------------------------- */
/* Buffer line utilities                                         */
/* ------------------------------------------------------------- */
bool ircg_isReply(immutable string line) @trusted nothrow
{
    try {
        return IRCReply(line).successful;
    } catch (Exception e) {
        return false;
    }
}

bool ircg_isPrivMsg(immutable string line) @trusted nothrow
{
    try {
        return line.split!isWhite()[1] == "PRIVMSG";
    } catch(Exception e) {
        assert(false);
    }
}

string ircg_noPrefix(immutable string line) @trusted nothrow
{
    try {
        return line.split!isWhite()[1..$].join(" ");
    } catch(Exception e) {
        assert(false);
    }
}


