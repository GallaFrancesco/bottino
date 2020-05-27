module bottino.bots.raver;

import bottino.bots;
import bottino.irc;
import bottino.ircgrammar;

import pegged.grammar;
import sumtype;
import vibe.core.file;


immutable command = "info";

Bot createRaverBot(immutable string name,
                  immutable BotConfig config,
                  ref IrcClient irc) @safe
{
    return Bot(name, command, "Dimmi chi sei e ti diro` a che festa andare", config, asBotAction!(raverWork!irc));
}

/* ----------------------------------------------------------------------- */

bool raverWork(alias IRC)(const BotConfig config, string line) @safe nothrow
{
    import std.array: join;
    import std.range: enumerate, tee;
    import std.algorithm: map, filter, each;
    import std.string: lineSplitter;
    import vibe.core.file: appendToFile, readFileUTF8, writeFileUTF8;

    auto cmd = IRCCommand(line);

    immutable store = "info.raverbot";
    void help_msg()@safe nothrow{
        cmd.reply!IRC("Infobot: il tuo infopusher", config);
        cmd.reply!IRC("'!info': bagno di fango", config);
        cmd.reply!IRC("'!info flyer <text>': dammi ste info va", config);
        cmd.reply!IRC("'!info del <n>': rimuovi il flyer numero n, parte da 0", config);
        cmd.reply!IRC("'!info help': questo help message", config);
    }

    void give_info()@safe nothrow{
        import std.format: format;
        try{
            if(!existsFile(store)) {
                cmd.reply!IRC("No info, fatti due contatti", config);
                return;
            }

            store.readFileUTF8()
                .lineSplitter
                .enumerate()
                .map!(t => format!"%d: %s"(t[0], t[1]))
                // .tee!print
                .each!(st => cmd.reply!IRC(st, config));
        }catch(Exception e){
            cmd.reply!IRC("Exception caught: "~e.msg, config);
        }
    }

    string remove_flyer(const uint n)@safe nothrow{
        import std.typecons: Tuple;
        import vibe.core.path: PosixPath;

        string ret;

        // filter but cache the target line
        bool ft(const Tuple!(ulong, string) t)@safe nothrow{
            if(t[0] == n){
                assert(ret == "");
                ret = t[1];
                return false;
            }
            return true;
        }

        try{
            auto remainings = store.readFileUTF8()
                .lineSplitter
                .enumerate()
                .filter!ft
                .map!(t => t[1])
                .join("\n");

            if(ret == "")
                return "The number is out of range";
            else{
                PosixPath(store).writeFileUTF8(remainings);
                return "Removed line: "~ret;
            }
        }catch(Exception e){
            return "There was an exception: "~e.msg;
        }
    }

    void save_flyer(const string text)@safe nothrow{
        try{
            store.appendToFile(text~"\n");
        }catch(Exception e){
        }
    }

    if(cmd.valid && cmd.command == command) {
        if(cmd.target != "#freiberg"){
            cmd.reply!IRC("Non sarai mica un pulotto?", config);
        }else{
            auto parsed_msg = parse(cmd.text);
            parsed_msg.match!((Error e) => cmd.reply!IRC(e, config),
                              (Help h) => help_msg(),
                              (InfoList l) => give_info(),
                              (Flyer flyer) { save_flyer(flyer.text); cmd.reply!IRC("Ci si becca sotto cassa", config); },
                              (DeleteFlyer n) { string st = remove_flyer(n); cmd.reply!IRC(st, config); });
        }

    }
    return true;
}

/* ----------------------------------------------------------------------- */

struct Flyer{
    string text;
}
struct DeleteFlyer{
    uint n;
    alias n this;
}
struct Error{
    string msg;
    alias msg this;
}
struct InfoList{
}
struct Help{
}

mixin(grammar(`
Comm:
   Start    <- (Flyer | Del | Help) 
   Flyer    <- "flyer" space Text
   Del      <- "del" space Number
   Help     <- "help" eoi 

   Text     <- (space / Char)*
   Char     <- .
   Number   <- ([0-9]+)
`));

alias Command = SumType!(Flyer, DeleteFlyer, Error, InfoList, Help);

Command parse(const string text) @trusted nothrow
{ // TODO: reduce trusted scope
    import std.array: join;
            
    typeof(return) ret;
    ParseTree pt;

    if(text == "") { ret = InfoList(); return ret; }
    try {
        pt = Comm(text);
    } catch(Exception e) {
        ret = Error(e.msg);
    }

    if(pt.successful){
        assert(pt.children.length == 1);
        assert(pt.name == "Comm");
        pt = pt.children[0];
        assert(pt.children.length == 1);
        assert(pt.name == "Comm.Start");
        pt = pt.children[0];

        switch(pt.name){
        case "Comm.Del":{
            assert(pt.children.length == 1);
            auto ch = pt.children[0];
            assert(ch.name == "Comm.Number");
            assert(ch.matches.length >= 1);
            try{
                import std.conv: to;
                uint n = to!uint(ch.matches.join());
                ret = DeleteFlyer(n);
            }catch(Exception e){
                ret = Error(e.msg);
            }
            break;
        }

        case "Comm.Help":
            ret = Help();
            break;

        case "Comm.Flyer":{
            assert(pt.children.length == 1);
            assert(pt.children[0].name == "Comm.Text");
            immutable flyer_text = pt.children[0].matches.join();
            ret = Flyer(flyer_text);
            break;
        }
        default: assert(false);
        }
        
    }else{
        ret = Error("La musica e` troppo forte, non capisco cosa mi stai dicendo");
    }

    return ret;
}
