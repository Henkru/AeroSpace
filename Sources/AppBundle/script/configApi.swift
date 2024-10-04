import Common

extension ScriptEngine {
    func createConfigApi() -> LuaTable {
        let cnf = LuaTable.empty(ctx: ctx)

        /* Sets the 'start-at-login' config option
         * @param value boolean
         *
         * Example:
         * aero.config.start_at_login(true)
         */
        cnf["start_at_login"] =
            ctx.createFunction { state in
                return ScriptEngine.functionWrapper(
                    state,
                    name: "aero.config.start_at_login",
                    expectedArgs: [.boolean]
                ) { args in
                    config.startAtLogin = args.at(1).asBool()!
                    return .none
                }
            }.asLuaValue

        /* Sets the 'enable-normalization-flatten-containers' config option
         * @param value boolean
         *
         * Example:
         * aero.config.enable_normalization_flatten_containers(true)
         */
        cnf["enable_normalization_flatten_containers"] =
            ctx.createFunction { state in
                return ScriptEngine.functionWrapper(
                    state,
                    name: "aero.config.enable_normalization_flatten_containers",
                    expectedArgs: [.boolean]
                ) { args in
                    config.enableNormalizationFlattenContainers = args.at(1).asBool()!
                    return .none
                }
            }.asLuaValue

        /* Sets the 'enable-normalization-opposite-orientation-for-nested-containers' config option
         * @param value boolean
         *
         * Example:
         * aero.config.enable_normalization_opposite_orientation_for_nested_containers(true)
         */
        cnf["enable_normalization_opposite_orientation_for_nested_containers"] =
            ctx.createFunction { state in
                return ScriptEngine.functionWrapper(
                    state,
                    name:
                    "aero.config.enable_normalization_opposite_orientation_for_nested_containers",
                    expectedArgs: [.boolean]
                ) { args in
                    config.enableNormalizationOppositeOrientationForNestedContainers = args.at(1)
                        .asBool()!
                    return .none
                }
            }.asLuaValue

        /* Sets the 'accordion-padding' config option
         * @param value int
         *
         * Example:
         * aero.config.accordion_padding(30)
         */
        cnf["accordion_padding"] =
            ctx.createFunction { state in
                return ScriptEngine.functionWrapper(
                    state,
                    name: "aero.config.accordion_padding",
                    expectedArgs: [.number]
                ) { args in
                    config.accordionPadding = args.at(1).asInteger()!
                    return .none
                }
            }.asLuaValue

        /* Sets the 'default-root-container-layout' config option
         * @param value string (possible values: tiles|accordion)
         *
         * Example:
         * aero.config.default_root_container_layout("tiles")
         */
        cnf["default_root_container_layout"] =
            ctx.createFunction { state in
                return ScriptEngine.functionWrapper(
                    state,
                    name: "aero.config.default_root_container_layout",
                    expectedArgs: [.string]
                ) { args in
                    switch args.at(1).asString() {
                        case "tiles":
                            config.defaultRootContainerLayout = .tiles
                        case "accordion":
                            config.defaultRootContainerLayout = .accordion
                        default:
                            args.ctx.yieldError("Invalid value for default-root-container-layout")
                    }
                    return .none
                }
            }.asLuaValue

        /* Sets the 'default-root-container-orientation' config option
         * @param value string (possible values: horizontal|vertical|auto)
         *
         * Example:
         * aero.config.default_root_container_orientation("auto")
         */
        cnf["default_root_container_orientation"] =
            ctx.createFunction { state in
                return ScriptEngine.functionWrapper(
                    state,
                    name: "aero.config.default_root_container_orientation",
                    expectedArgs: [.string]
                ) { args in
                    switch args.at(1).asString() {
                        case "horizontal":
                            config.defaultRootContainerOrientation = .horizontal
                        case "vertical":
                            config.defaultRootContainerOrientation = .vertical
                        case "auto":
                            config.defaultRootContainerOrientation = .auto
                        default:
                            args.ctx.yieldError("Invalid value for default-root-container-orientation")
                    }
                    return .none
                }
            }.asLuaValue

        return cnf
    }
}
