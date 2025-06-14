import std.stdio;
import std.process;
import sdlite;

int main(string[] args) {
    import std.file : exists;
    try {
        Config config;

        if (exists("gitfwd.sdl")) {
            config = getConfig(parseSDL("gitfwd.sdl"));
        }
        config = Config.fromEnvVars(config);

        if (!config.host) {
            if (environment.get("GITFWD_FALLBACK", "0") == "1") {
                Pid pid = spawnProcess(["git"]~args[1..$]);
                return pid.wait();
            }
            throw new Exception("No host specified! Is there a config file or env vars set?");
        }

        Pid pid = spawnProcess(["ssh"]~config.getConnectArgs(args[1..$]));
        return pid.wait();
    } catch (Exception ex) {
        stderr.writeln(ex.msg);
        return -1;
    }
}

struct Config {
    string user;
    string host;
    string cwd = ".";
    ushort port = 22;

    static Config fromEnvVars(Config existing) {
        import std.conv : to;

        Config result;
        result.host = environment.get("GITFWD_HOST", existing.host);
        result.user = environment.get("GITFWD_USER", existing.user);
        result.cwd = environment.get("GITFWD_CWD", existing.cwd);
        result.port = environment.get("GITFWD_PORT", existing.port.to!string).to!ushort;
        return result;
    }

    string[] getConnectArgs(string[] args) {
        import std.format : format;
        import std.conv : text;
        import std.array : join;

        string[] result;
        if (port != 22)
            result ~= ["-p", port.text];
        result ~= user ? "%s@%s".format(user, host) : host;
        result ~= [ "cd", cwd, ";" ];
        result ~= [ "git" ]~args;
        return result;
    }
}

SDLNode[] parseSDL(string file) {
    import std.file : readText;
    SDLNode[] result;
    parseSDLDocument!((n) { result ~= n; })(readText(file), file);
    return result;
}

Config getConfig(SDLNode[] nodes) {
    Config result;

    foreach(node; nodes) {
        switch(node.name) {
            case "host":
                result.host = cast(string)(node.values[0]);
                break;
            case "user":
                result.user = cast(string)(node.values[0]);
                break;
            case "port":
                result.port = cast(ushort)(cast(long)node.values[0]);
                break;
            
            default:
                continue;
        }
    }


    return result;
}