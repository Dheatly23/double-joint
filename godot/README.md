# Godot Example

This folder contains an implementation of Double Joint in Godot.
Open it with Godot 4. There is a default skin for testing, which
you can edit it with your own skin.

## Note About WASM

There are 2 implementation available, one pure GDScript (`model`), the other
is using WASM (`model_wasm`). To use the other one, please install
[godot-wasm](https://github.com/Dheatly23/godot-wasm)
and build the WASM binary
(the `Makefile.toml` should run the deployment for you).

## How to Embed

If you want to use it in your own project, copy the model folder.
The model scene has a skeleton which you can bind to and manipulate.
Because of limitations, **only** rotate joint bones, don't move the endpoint.

## License

All scripts are licensed under Apache-2.0 (same as repository).
Test skin image (`skin2.png`) is licensed under CC0.
