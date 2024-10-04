import CLua

enum LuaError: Error {
    case runtimeError(String)

    var message: String {
        switch self {
            case .runtimeError(let msg):
                return msg
        }
    }
}

extension LuaContext {
    func yieldError(_ msg: String) -> Never {
        self.push(.string(msg))
        lua_error(state)
        fatalError("lua_error should not return")  // Satisfies Swift's Never requirement
    }

    func popRuntimeErrorMessage() -> LuaError {
        let msg = String(cString: lua_tolstring(state, -1, nil))
        return .runtimeError(msg)
    }
}
