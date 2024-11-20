# NanoDriftGuard

NanoDriftGuard is a cutting-edge active stabilization software based on sub-pixel image registration and incremental PID control. Leveraging GPU-accelerated computing, this MATLAB-based solution delivers high-speed performance and exceptional 3D stability with precision down to the ångström scale.

## Table of Contents

- [NanoDriftGuard](#nanodriftguard)
  - [Table of Contents](#table-of-contents)
  - [Quick Start](#quick-start)
    - [Demo or Speed Test](#demo-or-speed-test)
    - [Running in Real-Time with Actual Devices](#running-in-real-time-with-actual-devices)
      - [Requirements](#requirements)
      - [Steps](#steps)
  - [Functions](#functions)
    - [Top-Level Function](#top-level-function)
    - [Core Functions \& Classes](#core-functions--classes)
    - [Utility Functions \& Classes](#utility-functions--classes)
  - [Limitations](#limitations)
  - [License](#license)

## Quick Start

### Demo or Speed Test

1. Install the following prerequisites on a computer with a CUDA-compatible GPU:

   - MATLAB R2023a or later
     - Parallel Computing Toolbox

2. Clone the repository
3. Open MATLAB and navigate to the project folder
4. Run the script [`Demo.m`](Demo.m) or [`Speedtest.m`](Speedtest.m)

### Running in Real-Time with Actual Devices

#### Requirements

- Specialized imaging system with fiducial marker detection capabilities
- GenTL-compatible camera
  - MATLAB Image Acquisition Toolbox
  - MATLAB Image Acquisition Toolbox Support Package for GenICam™ Interface
- Physik Instrumente (PI) nano-positioning stage
  - [PI Software Suite](https://www.physikinstrumente.com/en/products/software-suite)

> Note: Other hardware setups may require modifications to the control code.

#### Steps

1. Edit the example configuration file [`NDG_Config.ini`](NDG_Config.ini) according to your specific setup
2. Run the following code in the MATLAB command window:

    ```matlab
    initMatlab;
    lventry('NDG_Config.ini');
    ```

    If the settings are correct, you should see a figure displaying the initial image along with the linear fit. The command window will then print the running status.

> Note: The paths in the examples are configured for Windows-style path conventions. If you are using a different operating system, please modify the path-related code (e.g., `lvini2struct` in [`readConfig.m`](./Utils/readConfig.m)) accordingly.

## Functions

### Top-Level Function

- [`lventry`](./lventry.m): Entry point for the real-time control loop

### Core Functions & Classes

- [`regisXpress3`](./Utils/regisXpress3.m): High-efficiency 3D subpixel image registration with GPU acceleration, optimized for real-time applications
- [`PidManager`](./Utils/PidManager.m): Incremental PID controller for stage management, inherited from [`StageManager64`](./Utils/StageManager64.m)

### Utility Functions & Classes

- [`StageManager64`](./Utils/StageManager64.m): Custom PI stage control class
- [`fileManage`](./Utils/fileManage.m): File management utilities
- [`connectCam`](./Utils/connectCam.m) & [`getImg`](./Utils/getImg.m): Utility functions for GenTL camera connection and image acquisition
- [`getReference`](./Utils/getReference.m): Utility function for reference image acquisition and parameters of Z estimation
- [`readConfig`](./Utils/readConfig.m): Utility function for reading `ini` configuration file in LabVIEW format

## Limitations

This project does not include a GUI. You can create your own GUI for better visualization of the drift status using MATLAB figures or other platforms.

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.
