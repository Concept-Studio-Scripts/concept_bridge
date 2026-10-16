# Concept Bridge

Concept Studio's compatibility layer for FiveM frameworks, inventories and other providers. Supports ox_core, Qbox, QBCore and ESX. The resource folder must be named **concept_bridge**.

**Current release: 1.0.0** <!-- x-release-please-version -->

[Documentation](https://conceptstudio.store/docs/concept-bridge) · [Releases](https://github.com/Concept-Studio-Scripts/concept_bridge/releases/latest) · [Issues](https://github.com/Concept-Studio-Scripts/concept_bridge/issues)

## Installation

Download the resource ZIP from Releases and extract its `concept_bridge` folder into your resources directory. The repository also includes a prebuilt UI.

Requires OneSync, server artifact 6116 or newer, ox_lib and oxmysql. Start your providers before the bridge and consumer scripts afterward:

```cfg
ensure oxmysql
ensure ox_lib
# Start your framework, inventory and other providers here.
ensure concept_bridge
```

Configure the files in `settings/`. See the [documentation](https://conceptstudio.store/docs/concept-bridge) for provider selection, configuration, exports, events and integration requirements.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for development and releases, [test/README.md](test/README.md) for checks, and [web/README.md](web/README.md) for UI builds. Release notes are in [CHANGELOG.md](CHANGELOG.md).

## License and credits

Derived from [Community Bridge](https://github.com/TheOrderFivem/community_bridge), originally developed by The Order of the Sacred Framework and contributors. Distributed under the preserved [GPLv3 license](LICENSE); see [ORIGIN.Md](ORIGIN.Md) for credits.
