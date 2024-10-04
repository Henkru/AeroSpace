import CLua
import Common
import Foundation

typealias LuaRef = Int32
let LUA_OK: Int32 = 0

struct LuaContext {
    let state: OpaquePointer

    init(_ state: OpaquePointer?) {
        guard let state else {
            error("Lua state is nil")
        }
        self.state = state
    }

    static func new() -> LuaContext {
        guard let state = luaL_newstate() else {
            error("Failed to initialize Lua context")
        }
        luaL_openlibs(state)
        return LuaContext(state)
    }

    func close() {
        lua_close(state)
    }

    func reload() {
        lua_settop(state, 0)
        lua_createtable(state, 0, 0)
        lua_setfield(state, LUA_GLOBALSINDEX, "_G")
        luaL_openlibs(state)
    }

    func stackSize() -> Int {
        return Int(lua_gettop(state))
    }

    func load(file: URL) -> Result<LuaFunction, LuaError> {
        guard luaL_loadfile(state, file.path) == LUA_OK else {
            return .failure(popRuntimeErrorMessage())
        }
        return .success(LuaFunction.refAndPop(ctx: self))
    }

    func load(code: String) -> Result<LuaFunction, LuaError> {
        guard luaL_loadstring(state, code) == LUA_OK else {
            return .failure(popRuntimeErrorMessage())
        }
        return .success(LuaFunction.refAndPop(ctx: self))
    }

    func setGlobal(key: String, value: IntoLuaValue) {
        self.push(value.asLuaValue)
        lua_setfield(state, LUA_GLOBALSINDEX, key)
    }

    func getGlobal(key: String) -> LuaValue {
        lua_getfield(state, LUA_GLOBALSINDEX, key)
        return self.pop()
    }

    func ref() -> LuaRef {
        return luaL_ref(state, LUA_REGISTRYINDEX)
    }

    func ref(at: Int32) -> LuaRef {
        lua_pushvalue(state, at)  // Copy the value onto the top of the stack
        return self.ref()
    }

    func unref(_ ref: LuaRef) {
        luaL_unref(state, LUA_REGISTRYINDEX, ref)
    }

    func remove(_ n: Int) {
        lua_settop(state, Int32(-(n) - 1))
    }

    func pop() -> LuaValue {
        let value = self.from(at: -1)
        self.remove(1)
        return value
    }
}

extension LuaContext: Equatable {
    static func == (lhs: LuaContext, rhs: LuaContext) -> Bool {
        return lhs.state == rhs.state
    }
}
