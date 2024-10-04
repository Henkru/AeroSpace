import CLua

class LuaTable: IntoLuaValue {
    private let ctx: LuaContext
    let ref: Int32

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

    static func refAndPop(ctx: LuaContext) -> LuaTable {
        return LuaTable(ctx: ctx, reference: ctx.ref())
    }

    static func empty(ctx: LuaContext) -> LuaTable {
        lua_createtable(ctx.state, 0, 0)
        return LuaTable.refAndPop(ctx: ctx)
    }

    subscript(key: LuaValue) -> LuaValue {
        get {
            ctx.push(self.asLuaValue)
            ctx.push(key)
            lua_gettable(ctx.state, -2)
            let value = ctx.pop()
            ctx.remove(1)  // Remove the table ref from the stack
            return value
        }

        set {
            ctx.push(self.asLuaValue)
            ctx.push(key)
            ctx.push(newValue)
            lua_settable(ctx.state, -3)
            ctx.remove(1)  // Remove the table ref from the stack
        }
    }

    subscript(key: String) -> LuaValue {
        // Optimzed version for string keys
        // no need to push the string key into the stack
        get {
            ctx.push(self.asLuaValue)
            lua_getfield(ctx.state, -1, key)
            let val = ctx.pop()
            ctx.remove(1)  // remove the table ref from stack
            return val
        }

        set {
            ctx.push(self.asLuaValue)
            ctx.push(newValue)
            lua_setfield(ctx.state, -2, key)
            ctx.remove(1)  // Remove the table ref from the stack
        }
    }

    subscript(key: lua_Number) -> LuaValue {
        get {
            return self[.number(key)]
        }

        set {
            self[.number(key)] = newValue
        }
    }

    func fieldType(_ key: String) -> LuaValueType {
        ctx.push(self.asLuaValue)
        lua_getfield(ctx.state, -1, key)
        let type = ctx.luaType(at: -1)
        ctx.remove(2)
        return type
    }

    var asLuaValue: LuaValue {
        return .table(self)
    }
}

extension LuaTable: Equatable {
    static func == (lhs: LuaTable, rhs: LuaTable) -> Bool {
        return
            lhs.ctx == rhs.ctx && lhs.ref == rhs.ref
    }
}

extension LuaTable: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(ref)
    }
}
