![POMATO SOUP](https://raw.githubusercontent.com/richard-weinhold/pomato/main/docs/_static/graphics/pomato_logo_small.png) RedundancyRemoval for Fast Security Constraint Optimal Power Flow
=====================================================================================================================================
![RedundancyRemoval](https://github.com/richard-weinhold/RedundancyRemoval/workflows/RedundancyRemoval/badge.svg)

[![codecov](https://codecov.io/gh/richard-weinhold/RedundancyRemoval/branch/master/graph/badge.svg?token=MS3er8Qjbw)](https://codecov.io/gh/richard-weinhold/RedundancyRemoval)

Overview
--------

Determining contingency aware dispatch decisions by solving a security-constrained optimal power flow (SCOPF)is challenging for real-world power systems, as the high problem dimensionality often leads to impractical computational requirements. This problem becomes more severe when the SCOPF has to be solved not only for a single instance, but for multiple periods, e.g. in the context of electricity market analyses. The RedundancyRemoval algorithm identifies the minimal set of constraints that exactly define the space of feasible nodal injections for a given network and contingency scenarios.
Please see the corresponding publication for further information.

Installation
------------

The RedundancyRemoval algorithm can be cloned and added to you julia projects or just used from the repository. The algorithm requires Julia version >= 1.3 and works with the open Clp solver. However, especially with larger cases and parallel execution, Gurobi provides faster and more robust results.

This package is meant to be used in conjunction with the python [POMATO](https://github.com/richard-weinhold/pomato) model, which embeds its features and installs
it automatically. For stand alone usage see the documentation page or the example below:

[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://richard-weinhold.github.io/RedundancyRemoval/dev/)


Example
--------

The algorithm relies on the (N-1) PTDF, the corresponding line capacities and optionally upper/lower bounds on nodal injections as inputs.
The example folder contains these files compiled for the IEEE 118 bus network and the test folder uses a small example to illustrate its functionality.

The algorithm can be run for the exemplary data with the following code:

      using RedundancyRemoval
      wdir = <path to /examples>
      file_suffix = "ieee118"
      run_redundancy_removal(wdir, file_suffix)

The main function *run_redundancy_removal* can also directly take the input PTDF matrix *A*, line capacity vector *b* and the vector *x_bounds* as input, as shown in the *test/runtests.jl*.

Release Status
--------------

This algorithm finds use in the Power Market Tool [(POMATO)](https://github.com/richard-weinhold/pomato) and is developed for this purpose. This repository exists to make the algorithm also available on its own, however the development focus lies on its integration with POMATO.

Related Publications
--------------------

- [Weinhold and Mieth (2023), Uncertainty-Aware Capacity Allocation in Flow-Based Market
  Coupling](https://ieeexplore.ieee.org/abstract/document/10094020)
- [Weinhold (2022), Dissertation, Open-source modeling of flow based market
  coupling](https://depositonce.tu-berlin.de/items/d3b3a941-8c35-41b5-b404-f75034f971be) (Dissertation - Available from TU - Berlin). 
- [Weinhold (2021), Dissertation, Open-source modeling of flow based market
  coupling](https://depositonce.tu-berlin.de/items/d3b3a941-8c35-41b5-b404-f75034f971be) (Defence Slides). 
- [Weinhold and Mieth (2021), Power Market Tool (POMATO) for the Analysis of Zonal 
   Electricity Markets](https://www.sciencedirect.com/science/article/pii/S2352711021001394)
- [Weinhold and Mieth (2020), Fast Security-Constrained Optimal Power Flow through 
   Low-Impact and Redundancy Screening](https://ieeexplore.ieee.org/document/9094021)
- [Schönheit, Weinhold, Dierstein (2020), The impact of different strategies for generation 
   shift keys (GSKs) on  the flow-based market coupling domain: A model-based analysis of Central Western Europe](https://www.sciencedirect.com/science/article/pii/S0306261919317544)
