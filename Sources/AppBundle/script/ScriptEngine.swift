import Common
import Foundation

let defaultScriptEngine = ScriptEngine()

class ScriptEngine {
    let ctx = LuaContext.new()

    init() {
        let aero = LuaTable.empty(ctx: ctx)
        aero["api"] = createApi().asLuaValue
        aero["callbacks"] = createCallbacksApi().asLuaValue
        ctx.setGlobal(key: "aero", value: aero)
    }

    deinit {
        ctx.close()
    }

    func reload() -> Bool {
        ctx.reload()
        return runInitFile()
    }

    func runInitFile() -> Bool {
        let xdgConfigHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]?.lets {
            URL(filePath: $0)
        }
        let initLua = xdgConfigHome?.appending(path: "aerospace").appending(path: "init.lua")
        guard let initLua else {
            // TODO: print warning?
            return true
        }

        if FileManager.default.fileExists(atPath: initLua.path) {
            switch ctx.load(file: initLua) {
                case .failure(let err):
                    error("Failed to load init.lua: \(err)")
                case .success(let initFunc):
                    if case .err(let err) = ctx.call(initFunc, with: []) {
                        error("Failed to execute init.lua: \(err)")
                    }
            }
        }
        return true
    }
}
