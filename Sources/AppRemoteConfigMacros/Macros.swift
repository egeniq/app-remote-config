@attached(member, names: named(init), named(apply(settings:logger:)))
public macro AppRemoteConfigValues() =
#externalMacro(
    module: "AppRemoteConfigMacrosPlugin", type: "AppRemoteConfigValuesMacro"
)
