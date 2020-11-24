===================================
Welcome to Kuberef's documentation!
===================================

Introduction
============

Kuberef aims to develop and deliver a Kubernetes-based reference
implementation according to CNTT RA-2 in close collaboration with the
CNTT RI-2 workstream.

.. note::

    This is just an example of a possible RI-2 deployment. Kuberef aims to
    support and include other potential hardware and Kubernetes deployers as well. More
    details can be found in the `Kuberef Wiki <https://wiki.opnfv.org/spaces/viewspace.action?key=KUB>`_.

Infrastructure Prerequisites
=============================

Please refer to Chapter 3 of `CNTT RI-2 Documentation <https://github.com/cntt-n/CNTT/blob/master/doc/ref_impl/cntt-ri2/chapters/chapter03.md>`_
for detailed information on the server and network specifications.

Additionally, please make note of the following:

1. Ensure that you have KVM installed and set up on your jump server. This is needed
   because the deployment will spin up a VM which will then carry out the host and
   Kubernetes installation.

2. Generate SSH keypair.

3. Add user to the sudo and libvirt group and have passwordless sudo enabled.

4. Install Ansible (tested with 2.9.14) and yq.

Deployment
=============================

Please refer to Chapter 4 of `CNTT RI-2 Documentation <https://github.com/cntt-n/CNTT/blob/master/doc/ref_impl/cntt-ri2/chapters/chapter04.md>`_
for instructions to get started with the deployment.

Once the deployment is successful, you will have a fully functional RI-2 setup!

Validation of the Reference Implementation
===========================================

Kuberef has been validated by running test cases defined in CNTT RC2 Cookbook.
For setting up RC2 Conformance toolchain, please refer to `CNTT RC-2 Chapter 03 <https://github.com/cntt-n/CNTT/blob/master/doc/ref_cert/RC2/chapters/chapter03.md>`_.
