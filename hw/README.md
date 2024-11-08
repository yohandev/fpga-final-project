## Installation
These steps are for development in Visual Studio Code:
1. Clone the repository (`git clone git@github.com:yohandev/fpga-final-project.git`)
2. Open this folder (`client/`) in VSCode
3. Create a Python virtual environment (`Cmd+Shift+P` > `Python: Create Environment...`)
4. Ensuring the environment is active (the VSCode terminal will do this automatically), install `cocotb` (`pip install cocotb`)
5. Install `lab-bc-client`
    1. `git clone https://github.com/jodalyst/lab_bc_client.git`
    2. `cd lab_bc_client`
    3. `pip install .`
    4. `cd .. && rm -rf lab_bc_client` (optional)

## Building & Flashing
1. Run the VSCode task (`Cmd+Shift+P` > `Tasks: Run Task` > `Build with lab-bc`)
    1. For me, a buttons shows up at the bottom of the window
2. Ditto for flashing `Upload to FPGA`