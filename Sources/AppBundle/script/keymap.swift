import Common

extension ScriptEngine {
    func createKeymapApi() -> LuaTable {
        let keymap = LuaTable.empty(ctx: ctx)

        /* Sets a key binding for the given mode.
         * @param mode        string
         * @param key         string
         * @param command...  string | function
         *
         * Example:
         * aero.keymap.set("main", "alt-1", "workspace 1")
         * aero.keymap.set("service", "esc", "reload-config", "mode main")
         * aero.keymap.set("service", "h", function() print("hello from key binding") end)
         */
        keymap["set"] =
            ctx.createFunction { state in
                return ScriptEngine.functionWrapper(
                    state,
                    name: "aero.keymap.set",
                    expectedArgs: [
                        .string,  // mode
                        .string,  // key
                        .multi([.string, .function]),  // command string or function
                        .variadic(.multi([.string, .function])),  // ...
                    ]
                ) { args in
                    let mode = args.at(1).asString()!
                    let rawKey = args.at(2).asString()!

                    // Convert the command arguments to actual Aero commands
                    let commands = (3 ... args.count).compactMap {
                        switch ScriptEngine.argToCommand(args.at($0)) {
                            case .success(let command):
                                return command
                            case .failure(let err):
                                args.ctx.yieldError(err)
                        }
                    }

                    // Parse the key string to modifier and key combo
                    guard
                        case .success(let (mod, key)) = parseBinding(
                            rawKey, .root, config.keyMapping.resolve())
                    else {
                        return .single(.boolean(false))
                    }

                    // Ensure the mode exists
                    if config.modes[mode] == nil {
                        config.modes[mode] = Mode(name: mode, bindings: [:])
                    }

                    // Create the key binding
                    let hotkey = HotkeyBinding(
                        mod, key, commands, descriptionWithKeyNotation: rawKey)
                    config.modes[mode]!.bindings[hotkey.descriptionWithKeyNotation] = hotkey

                    // Refresh keybindings if the mode is currently selected
                    if mode == activeMode {
                        activateMode(mode)
                    }

                    return .single(.boolean(true))
                }
            }.asLuaValue
        /* Removes a key binding from the given mode.
         * @param mode        string
         * @param key         string
         *
         * Example:
         * aero.keymap.del("main", "alt-1")
         */
        keymap["del"] =
            ctx.createFunction { state in
                return ScriptEngine.functionWrapper(
                    state,
                    name: "aero.keymap.del",
                    expectedArgs: [
                        .string,  // mode
                        .string,  // key
                    ]
                ) { args in
                    let mode = args.at(1).asString()!
                    let rawKey = args.at(2).asString()!

                    // If mode does not exists, then we're done
                    if config.modes[mode] == nil {
                        return .single(.boolean(true))
                    }

                    config.modes[mode]!.bindings.removeValue(forKey: rawKey)

                    // Refresh keybindings if the mode is currently selected
                    if mode == activeMode {
                        activateMode(mode)
                    }

                    return .single(.boolean(true))
                }
            }.asLuaValue
        return keymap
    }
}
