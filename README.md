# 6.2050 Final Project
## FPGA Minecraft Raytracer

This is the repository for our final project in MIT's 6.2050 FPGA class. At the root, find PDF exports of the class deliverables. `hw/` contains the SystemVerilog code which runs on a Xilinx Spartan7 FPGA. `sw/` is a software implementation of that same code (more or less), used for testing and characterizing. `plugin/` is a Java program that plugs into a standard Minecraft server.

## Installation & Workflow
First, clone the repo including its submodules.
```
git submodule init
git submodule update --recursive
```

Next, open the root of this repository in Visual Studio Code.


### Server
This is using [Feather](https://github.com/feather-rs/feather), a Rust re-implementation of a Minecraft server. It's very barebones and for our purposes, that's perfect. I've written VSCode tasks for just about everything, but you will need to [install the Rust toolchain](https://www.rust-lang.org/tools/install) first.

Next, let's start the server. In VSCode, run the `Start Server` task. This will appear on the bottom task bar; if not, `Cmd + Shift + P > Tasks: Run Task > Start Server`. This does a few things:
1. Builds the Feather server. Takes a minute or so the first time; no-op every subsequent time.
2. Builds the plugin. This is the part we're implementing, and it lives in `server/plugin/`
3. Copies over all the artifacts into `server/dummy`. That folder will eventually be populated with server configs, world files, etc.
4. Starts the server

Now you can join the server (in "multiplayer", click "Join Server" and go to `localhost`).

### Hardware
TODO