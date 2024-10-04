import Common

extension ScriptEngine {
    static func argToCommand(_ arg: LuaValue) -> Result<(any Command), String> {
        switch arg {
            case .string(let command):
                return command.splitArgs().map { parseCommand($0).unwrap() }
                    .flatMap { (args) in
                        if let command = args.0 {
                            return .success(command)
                        } else {
                            return .failure(args.2 ?? "Could not parse command from Lua argument")
                        }
                    }
            case .function(let f):
                return .success(
                    ExecuteLuaFunctionCommand(
                        args: EmptyCmdArgs(rawArgs: []), function: f))
            default:
                error("unreachable")
        }
    }
}
