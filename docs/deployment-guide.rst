===================================
Welcome to Kuberef's documentation!
===================================

Introduction
============

Kuberef aims to develop and deliver a Kubernetes-based reference
implementation according to CNTT RA-2 in close collaboration with the
CNTT RI-2 workstream.

The entire implementation is divided into two stages - Host provisioning
and Kubernetes provisioning.

This guide describes how to get started with a potential RI-2 deployment
using `Cloud Infra Automation Framework <https://docs.nordix.org/submodules/infra/engine/docs/user-guide.html#framework-user-guide>`_
for the Host provisioning stage and Intel's `BMRA <https://github.com/intel/container-experience-kits>`_
for the Kubernetes provisioning stage.

.. note::

    This is just an example of a possible RI-2 deployment. Kuberef aims to
    support and include other potential hardware and Kubernetes deployers as well. More
    details can be found in the `Kuberef Wiki <https://wiki.opnfv.org/spaces/viewspace.action?key=KUB>`_.

Infrastructure Prerequisites
=============================

You need one physical server acting as a jump server along with minimum of two additional
servers on which RI-2 will be deployed. Please refer to Chapter 3 in CNTT RI-2 Documentation
for detailed information on the server and network specifications.

Additionally, please make sure that you have KVM installed and set up on your jump server. This
is needed because the deployment will spin up a VM which will then carry out the host and
Kubernetes installation.

Deployment
=============================

Before initiating the deployment, please note the following:

1. Add your configuration templates, ``pdf.yaml`` and ``idf.yaml`` under ``hw_config/<vendor>``.

2. Modify the environmental variables defined in ``deploy.env`` to match your setup.

3. Update ``hw_config/<vendor>/setup_network.sh`` with your correct networking info. This particular
   script sets up networking on the provisioned nodes after the host provisioning stage is successful.

.. note::

    Depending on your setup, this script might not be needed. #WIP

Once ready, issue the following command to initiate the deployment

.. code-block:: bash

   ./deploy.sh


Once the deployment is successful, you will have a fully functional RI-2 setup!
