```
git submodule init
git submodule update --recursive
rustup target add wasm32-wasi
cd feather
cargo build --release
```