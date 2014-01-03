module process_stats;

import core.time;

struct Stats {
    int exitCode;
    TickDuration totalTime;
    ulong maxMemKB;
}

version (linux) {
    import core.sys.posix.sys.resource;
    extern(C) pid_t wait4(pid_t pid, int* status, int options, rusage* rusage);

    Stats executeWithStats(alias spawnFunc, SpawnArgs...)(SpawnArgs spawnArgs) {
        import core.stdc.errno;
        import core.sys.posix.sys.wait;
        import std.datetime;
        import std.exception;

        Stats result;

        auto sw = StopWatch(AutoStart.yes);
        auto pid = spawnFunc(spawnArgs).processID();
        enforce(pid != -2);

        rusage usage;
        while (true) {
            int status;
            auto check = wait4(pid, &status, 0, &usage);

            if (check == -1) {
                assert(errno == EINTR);
                continue;
            }

            if (WIFEXITED(status)) {
                result.exitCode = WEXITSTATUS(status);
                break;
            } else if (WIFSIGNALED(status)) {
                result.exitCode = -WTERMSIG(status);
                break;
            }
        }

        sw.stop();
        result.totalTime = sw.peek();

        result.maxMemKB = usage.ru_maxrss;
        enforce(result.maxMemKB != 0,
            "Could not determine memory usage, kernel older than 2.6.32?");

        return result;
    }

} else {
    static assert(0, "Platform not yet supported.");
}
