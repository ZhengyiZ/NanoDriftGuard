# NanoDriftGuard

NanoDriftGuard is a high-speed active stabilization algorithm based on sub-pixel image registration and incremental PID control, implemented in MATLAB.

The algorithm provides exceptional stability, capable of achieving precision down to the ångström level in a closed-loop control system by actively stabilizing fiducial marker positions.

## Quick Start

1. Install all required dependencies (see [Prerequisites](#prerequisites))
2. Clone the repository
3. Open MATLAB and navigate to the project folder
4. Edit the example configuration file [`NDG_Config.ini`](NDG_Config.ini), then run:

    ```matlab
    lventry('NDG_Config.ini');
    ```

### Notes

- A history file (.csv) and autosave folder will be created as specified in the configuration file
- To abort the program, create the abort file in the directory specified in the configuration file

## Prerequisites

### Hardware

- GPU supporting CUDA
- Physik Instrumente (PI) nano-positioning stage
- GenTL-compatible camera

Custom hardware will require modifications to the control code.

### Software

- MATLAB R2023a or later
  - Image Acquisition Toolbox
    - Image Acquisition Toolbox Support Package for GenICam™ Interface
  - Parallel Computing Toolbox
- [PI Software Suite](https://www.physikinstrumente.com/en/products/software-suite)

## Functions

### Top-level functions

- [`initMATLAB`](./initMATLAB.m): Initialize the MATLAB environment
- [`lventry`](./lventry.m): Entry point for the demo function

### Core functions & classes

- [`PidManager`](./Utils/PidManager.m): Incremental PID controller for stage management, inherited from [`StageManager64`](./Utils/StageManager64.m)
- [`regisXpress3`](./Utils/regisXpress3.m): High-efficiency 3D subpixel image registration with GPU acceleration, optimized for repeated calls

### Utility functions & classes

- [`StageManager64`](./Utils/StageManager64.m): Custom PI stage control class
- [`fileManage`](./Utils/fileManage.m): File management utilities
- [`connectCam`](./Utils/connectCam.m) & [`getImg`](./Utils/getImg.m): Utility functions for GenTL camera connection and image acquisition
- [`getReference`](./Utils/getReference.m): Utility function for reference image acquisition and parameters of Z estimation

## Limitations

This project does not provide a GUI interface. You can create your own GUI interface for previewing images using MATLAB figures or other coding platforms like LabVIEW.

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.
