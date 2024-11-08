# 6.2050 Final Project
## FPGA Minecraft Raytracer

This is the repository for our final project in MIT's 6.2050 FPGA class. At the root, find PDF exports of the class deliverables. `hw/` contains the SystemVerilog code which runs on a Xilinx Spartan7 FPGA. `sw/` is a software implementation of that same code (more or less), used for testing and characterizing. `plugin/` is a Java program that plugs into a standard Minecraft server.

## Installation & Workflow
Clone the repo and open it in Visual Studio Code.


### Server
This is using [Feather](https://github.com/feather-rs/feather), a Rust re-implementation of a Minecraft server. It's very barebones and for our purposes, that's perfect. I've written VSCode tasks for just about everything, but you will need to [install the Rust toolchain](https://www.rust-lang.org/tools/install) first.

Next, let's start the server. In VSCode, run the `Start Server` task. This will appear on the bottom task bar; if not, `Cmd + Shift + P > Tasks: Run Task > Start Server`. This does a few things:
1. Builds the Feather server. Takes a minute or so the first time; no-op every subsequent time.
2. Builds the plugin. This is the part we're implementing, and it lives in `server/plugin/`
3. Copies over all the artifacts into `server/dummy`. That folder will eventually be populated with server configs, world files, etc.
4. Starts the server

Now you can join the server (in "multiplayer", click "Join Server" and go to `localhost`).

### Hardware
1. Open this repository in VSCode.
3. Create a Python virtual environment (`Cmd+Shift+P` > `Python: Create Environment...`)
4. Ensuring the environment is active (the VSCode terminal will do this automatically), install `cocotb` (`pip install cocotb`)
5. Install `lab-bc-client`
    1. `git clone https://github.com/jodalyst/lab_bc_client.git`
    2. `cd lab_bc_client`
    3. `pip install .`
    4. `cd .. && rm -rf lab_bc_client` (optional)

Now, you can build an flash:
1. Run the VSCode task (`Cmd+Shift+P` > `Tasks: Run Task` > `Build with lab-bc`)
    1. For me, a buttons shows up at the bottom of the window
2. Ditto for flashing `Upload to FPGA`