import CLua

class LuaFunction: IntoLuaValue {
    let ctx: LuaContext
    let ref: LuaRef

    init(ctx: LuaContext, at: Int32) {
        self.ctx = ctx
        self.ref = ctx.ref(at: at)
    }

    init(ctx: LuaContext, reference: LuaRef) {
        self.ctx = ctx
        self.ref = reference
    }

    deinit {
        ctx.unref(ref)
    }

    static func refAndPop(ctx: LuaContext) -> LuaFunction {
        return LuaFunction(ctx: ctx, reference: ctx.ref())
    }

    func call(args: [LuaValue]) -> LuaFunctionResult {
        return ctx.call(self, with: args)
    }

    func call(arg: LuaValue) -> LuaFunctionResult {
        return ctx.call(self, with: arg)
    }

    var asLuaValue: LuaValue {
        return .function(self)
    }
}

extension LuaContext {
    func call(_ f: LuaFunction, with args: [LuaValue]) -> LuaFunctionResult {
        // Required to calculated the number of returned arguments
        let stackSizeBeforeCall = self.stackSize()

        // Push the function and arguments onto the stack
        self.push(f.asLuaValue)
        args.forEach { self.push($0) }

        return call_inner(f, argCount: args.count, stackSizeBeforeCall: stackSizeBeforeCall)
    }

    func call(_ f: LuaFunction, with arg: LuaValue) -> LuaFunctionResult {
        // Required to calculated the number of returned arguments
        let stackSizeBeforeCall = self.stackSize()

        // Push the function and arguments onto the stack
        self.push(f.asLuaValue)
        self.push(arg)

        return call_inner(f, argCount: 1, stackSizeBeforeCall: stackSizeBeforeCall)
    }

    private func call_inner(_ f: LuaFunction, argCount: Int, stackSizeBeforeCall: Int)
        -> LuaFunctionResult
    {
        let callResult = lua_pcall(state, Int32(argCount), LUA_MULTRET, 0)
        guard callResult == LUA_OK else {
            return .err(popRuntimeErrorMessage())
        }

        // Pop the returned value(s)
        let returnCount = self.stackSize() - stackSizeBeforeCall
        switch returnCount {
            case 0:
                return .none
            case 1:
                return .single(self.pop())
            default:
                // The function results are pushed onto the stack in direct order (the first result is pushed first)
                let values = (-returnCount ..< 0).compactMap { self.from(at: $0) }
                self.remove(returnCount)
                return .many(values)
        }
    }

    func createFunction(
        _ function: lua_CFunction
    ) -> LuaFunction {
        lua_pushcclosure(state, function, 0)
        return LuaFunction.refAndPop(ctx: self)
    }
}

extension LuaFunction: Equatable {
    static func == (lhs: LuaFunction, rhs: LuaFunction) -> Bool {
        return
            lhs.ctx == rhs.ctx && lhs.ref == rhs.ref
    }
}

extension LuaFunction: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(ref)
    }
}

enum LuaFunctionResult {
    case none
    case single(LuaValue)
    case many([LuaValue])
    case err(LuaError)
}
