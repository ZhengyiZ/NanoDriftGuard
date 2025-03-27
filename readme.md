# NanoDriftGuard

[![DOI](https://img.shields.io/badge/DOI-10.1016%2Fj.optlaseng.2025.108957-blue.svg)](https://doi.org/10.1016/j.optlaseng.2025.108957) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

This repository contains the official implementation of the research described in:

> *NanoDriftGuard:* open-source isotropic ångström-scale active stabilization for super-resolution microscopy
>
> [![Xiaofan Sun](https://img.shields.io/badge/Xiaofan%20Sun-181717?logo=github&logoColor=white)](https://github.com/xiaohei333) [![Zhengyi Zhan](https://img.shields.io/badge/Zhengyi%20Zhan-181717?logo=github&logoColor=white)](https://github.com/ZhengyiZ) [![Chenying He](https://img.shields.io/badge/Chenying%20He-181717?logo=github&logoColor=white)](https://github.com/Haibara647) et al.
<!-- This should be updated after username changed. -->

*Any reuse of this code should cite the original associated publication.*

## Introduction

Advanced active stabilization software achieving ångström-scale precision through sub-pixel image registration and incremental PID control. Built in MATLAB with GPU acceleration, NanoDriftGuard delivers real-time 3D drift correction at >50 Hz rates, making it ideal for ultra-high-precision microscopy applications. Its language-agnostic file I/O interface enables seamless integration with any programming environment, offering exceptional flexibility for diverse experimental setups.

<details>
<summary><kbd>Table of Contents</kbd></summary>

## TOC

- [NanoDriftGuard](#nanodriftguard)
  - [Introduction](#introduction)
  - [TOC](#toc)
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
  - [Citation \& Reference](#citation--reference)
  - [License](#license)

<br/>

</details>

## Quick Start

### Demo or Speed Test

1. Install the following prerequisites on a computer with a CUDA-compatible GPU:

   - MATLAB R2023a or later
     - Parallel Computing Toolbox

2. Clone the repository
3. Open MATLAB and navigate to the project folder
4. Run the script [`Demo.m`](Demo.m) or [`Benchmark.m`](Benchmark.m)

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

## Citation & Reference

If you use this work in your research, please cite [![DOI](https://img.shields.io/badge/DOI-10.1016%2Fj.optlaseng.2025.108957-blue.svg)](https://doi.org/10.1016/j.optlaseng.2025.108957):

``` bibtex
@article{sunNanoDriftGuardOpensourceIsotropic2025,
    author = {Sun, Xiaofan and Zhan, Zhengyi and He, Chenying and Luo, Xin and Han, Yubing and Li, Chuankang and Kuang, Cuifang and Liu, Xu},
    title = {NanoDriftGuard: Open-source Isotropic {\AA}ngstr{\"o}m-Scale Active Stabilization for Super-Resolution Microscopy},
    year = {2025},
    doi = {10.1016/j.optlaseng.2025.108957},
    journal = {Optics and Lasers in Engineering}
}
```

This project builds upon *Efficient subpixel image registration algorithms* [![DOI](https://img.shields.io/badge/DOI-10.1364/OL.33.0000156-blue)](https://doi.org/10.1364/OL.33.000156)

``` bibtex
@article{guizar-sicairosEfficientSubpixelImage2008,
    author = {Guizar-Sicairos, Manuel and Thurman, Samuel T. and Fienup, James R.},
    title = {Efficient Subpixel Image Registration Algorithms},
    year = {2008},
    doi = {10.1364/OL.33.000156},
    journal = {Optics Letters}
}
```

## License

This project incorporates code from [![File Exchange](https://img.shields.io/badge/MATLAB%20File%20Exchange-Efficient%20subpixel%20image%20registration-blue.svg)](https://ww2.mathworks.cn/matlabcentral/fileexchange/18401-efficient-subpixel-image-registration-by-cross-correlation), which is licensed under the [BSD 3-Clause License](./Utils/dftregistration.m).

*NanoDriftGuard* modifications are licensed under the [MIT License](./LICENSE).
