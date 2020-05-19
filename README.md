[![PomatoLogo](https://github.com/richard-weinhold/pomato/blob/master/docs/pomatologo_small.png "Pomato Soup")](#) RedundancyRemoval for Fast Security Constraint Optimal Power Flow
=====================================================================================================================================
[![Build Status](https://travis-ci.org/richard-weinhold/RedundancyRemoval.svg?branch=master)](https://travis-ci.org/richard-weinhold/RedundancyRemoval)


Overview
--------

Determining contingency aware dispatch decisions by solving a security-constrained optimal power flow (SCOPF)is challenging for real-world power systems, as the high prob-lem dimensionality often leads to impractical computationalrequirements. This problem becomes more severe when theSCOPF has to be solved not only for a single instance, butfor multiple periods, e.g. in the context of electricity marketanalyses. The RedundancyRemoval algorithm identifies the minimal set of constraints that exactly define the space of feasiblenodal injections for a given network and contingency scenarios.
Please see the corresponding publication for further information.

Installation
------------

The RedundancyRemoval algorithm can be cloned and added to you julia projects or just used from the repository. The algorithm reequires Julia 1.3 and works with the open Clp solver. However, espeacially with larger cases and parallel execution, Gurobi provides faster and more robust results.

Example
--------

The algorithm relies on the (N-1) PTDF, the corresponding line capacities and optionally upper/lower bounds on nodal injections as inputs.
The example folder contains these files compiled for the IEEE 118 bus network and the test folder uses a small example to illustrate its functionality.

The algorithm can be run for the examplary data with the followig code:

      using RedundancyRemoval
      wdir = <path to /examples>
      file_suffix = "ieee118"
      run_redundancy_removal(wdir, file_suffix)

The main function *run_redundancy_removal* can also directly take the input PTDF matrix *A*, line capacity vector *b* and the vector *x_bounds* as input, as shown in the *test/runtests.jl*.

Release Status
--------------

This algorithm finds use in the Power Market Tool [(POAMTO)](https://github.com/richard-weinhold/pomato) and is developed for thios purpose. This repository exists to make the algorithm also available on its own, however the development focus lies on POMATO.

Related Publications
--------------------

- [Weinhold and Mieth (2019), Fast Security-Constrained Optimal Power Flow through
   Low-Impact and Redundancy Screening](https://arxiv.org/abs/1910.09034)
- [Schönheit, Weinhold, Dierstein (2020), The impact of different strategies for generation shift keys (GSKs) on the flow-based market coupling domain: A model-based analysis of Central Western Europe](https://www.sciencedirect.com/science/article/pii/S0306261919317544)
