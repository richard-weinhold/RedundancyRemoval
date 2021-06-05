
![POMATO SOUP](https://raw.githubusercontent.com/richard-weinhold/pomato/main/docs/_static/graphics/pomato_logo_small.png) RedundancyRemoval for Fast Security Constraint Optimal Power Flow
=====================================================================================================================================
![RedundancyRemoval](https://github.com/richard-weinhold/RedundancyRemoval/workflows/RedundancyRemoval/badge.svg)

Overview
--------

Determining contingency aware dispatch decisions by solving a security-constrained optimal power flow (SCOPF)is challenging for real-world power systems, as the high problem dimensionality often leads to impractical computational requirements. This problem becomes more severe when the SCOPF has to be solved not only for a single instance, but for multiple periods, e.g. in the context of electricity market analyses. The RedundancyRemoval algorithm identifies the minimal set of constraints that exactly define the space of feasible nodal injections for a given network and contingency scenarios.
Please see the corresponding publication for further information.

Installation
------------

This package is meant to be used in conjunction with the python
[POMATO](https://github.com/richard-weinhold/pomato) model, which embeds its features and installs
it automatically. 

Stand alone usage is possible, however specificity formatted data. 

Installation can be done directly from git via: 

```
] add https://github.com/richard-weinhold/RedundancyRemoval
```

or from a local clone/fork of the repository via: 

```
] add develop --local path-to-repository
```

The recommended julia version is 1.5, although compatibility is given for version >= 1.3, but not
continuously tested. 


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

Exposed function of the MarketModel
-----------------------------------

```@docs
run_redundancy_removal
```

```@docs
run_redundancy_removal_fbmc_domain
```

Related Publications
--------------------
- (*preprint*) [Weinhold and Mieth (2020), Power Market Tool (POMATO) for the Analysis of Zonal 
   Electricity Markets](https://arxiv.org/abs/2011.11594)
- [Weinhold and Mieth (2020), Fast Security-Constrained Optimal Power Flow through 
   Low-Impact and Redundancy Screening](https://ieeexplore.ieee.org/document/9094021)
- [Schönheit, Weinhold, Dierstein (2020), The impact of different strategies for generation 
   shift keys (GSKs) on  the flow-based market coupling domain: A model-based analysis of Central Western Europe](https://www.sciencedirect.com/science/article/pii/S0306261919317544)


