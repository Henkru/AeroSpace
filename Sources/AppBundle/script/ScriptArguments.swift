import Common

struct ScriptArguments {
    let count: Int
    let ctx: LuaContext

    private init(_ ctx: LuaContext) {
        self.ctx = ctx
        self.count = Int(self.ctx.stackSize())
    }

    static func fromState(_ state: OpaquePointer?) -> ScriptArguments {
        return ScriptArguments(LuaContext(state))
    }

    func kind(at: Int) -> LuaValueType {
        guard abs(at) <= count else {
            error(
                "Failed to query \(at). argument type, only \(count) arguments were provided"
            )
        }
        return ctx.luaType(at: at)
    }

    func collect() -> [LuaValue] {
        return (1 ... count).compactMap { self.at(Int($0)) }
    }

    func at(_ index: Int) -> LuaValue {
        guard abs(index) <= count else {
            error(
                "Failed to extract \(index). argument, only \(count) arguments were provided"
            )
        }
        return ctx.from(at: index)
    }
}
