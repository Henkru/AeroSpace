import AppKit
import Common

struct ExecuteLuaFunctionCommand: Command {
    let args: EmptyCmdArgs
    let function: LuaFunction

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        check(Thread.current.isMainThread)

        let envArg = LuaTable.empty(ctx: function.ctx)
        envArg["windowID"] = env.windowId.map { $0.asLuaValue } ?? .nil
        envArg["workspaceName"] = env.workspaceName.map { .string($0) } ?? .nil
        envArg["pwd"] = env.pwd.map { .string($0) } ?? .nil

        guard case .err = function.call(args: [.table(envArg)]) else {
            return false
        }
        return true
    }
}
