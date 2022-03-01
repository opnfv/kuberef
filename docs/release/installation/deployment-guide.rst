.. SPDX-FileCopyrightText: 2021 Anuket contributors
..
.. SPDX-License-Identifier: CC-BY-4.0

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

2. A non-root user and generate SSH keypair.

3. Add user to the sudo and libvirt group and have passwordless sudo enabled.

4. Install Python3 (tested with 3.6.9), Ansible (tested with 2.9.14), Docker, yq (v3.4.1), git, jq and virtual-env (16.2 or later).

Installing and configuring the prerequisites will depend on the operating system installed on the jump server.
Below are additional details for setting up some of the more popular distributions.

**Ubuntu 18.04 LTS**

.. note::

    Can not work on Ubuntu 20.04 because openstack ironic will install package libvirt-bin which
    has been split into libvirt-daemon-system and libvirt-clients from Ubuntu 18.10.

Install packages using Apt

* ``sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients libvirt-dev genisoimage virt-manager bridge-utils python3-libvirt git jq``
* Some of the packages might be installed already
* Start libvirtd if it isn't running using ``sudo service libvirtd start``
* Add user to libvirt group using ``sudo adduser `id -un` libvirt``
* Log out and in on the current user to update the groups

If ``python`` isn't available in the path, consider adding a symlink for Python3

* ``ln -s /usr/bin/python3 /usr/bin/python``

Install Ansible

* ``apt-add-repository --yes --update ppa:ansible/ansible``
* ``apt-get install ansible``

Install Docker

* ``sudo apt-get install docker.io``

Install ``yq`` binary from Github

* Find the correct build of version `v3.4.1 <https://github.com/mikefarah/yq/releases/tag/3.4.1>`_
* Place the binary in ``/usr/bin/yq`` and make it executable ``chmod +x /usr/bin/yq``

Install virtual-env

* ``pip install --upgrade virtualenv``

You might need to update the libvirt (QEMU) configuration if there are problems with user and group

* You can set the user and group to "root" by uncommenting `user` and `group` in ``/etc/libvirt/qemu.conf``
* If the configuration is changed, finish by restarting libvirtd through ``service libvirtd restart``

Generate SSH keypair

* ``ssh-keygen -t rsa -b 4096``

**CentOS 8**

Install packages using dnf

* ``dnf install qemu-kvm qemu-img libvirt virt-install libvirt-client python3 git jq``
* Some of the packages might be installed already
* Start libvirtd if it isn't running using ``service libvirtd restart``
* Add user to libvirt group using ``usermod -a -G libvirt $(whoami)``
* Log out and in on the current user to update the groups

If ``python`` isn't available in the path, consider adding a symlink for Python3

* ``ln -s /usr/bin/python3 /usr/bin/python``

Install Ansible
* ``dnf install epel-release``
* ``dnf install ansible``

Install ``yq`` binary from Github

* Find the correct build of version `v3.4.1 <https://github.com/mikefarah/yq/releases/tag/3.4.1>`_
* Place the binary in ``/usr/bin/yq`` and make it executable ``chmod +x /usr/bin/yq``

You might need to update the libvirt (QEMU) configuration if there are problems with user and group

* You can set the user and group to "root" by uncommenting `user` and `group` in ``/etc/libvirt/qemu.conf``
* If the configuration is changed, finish by restarting libvirtd through ``service libvirtd restart``

Generate SSH keypair

* ``ssh-keygen -t rsa -b 4096``

Deployment on Baremetal and Provider Infrastructure
===================================================

Please refer to Chapter 4 of `CNTT RI-2 Documentation <https://github.com/cntt-n/CNTT/blob/master/doc/ref_impl/cntt-ri2/chapters/chapter04.md>`_
for instructions to get started with the deployment.

Deployment on Virtualized Infrastructure
========================================

Following are the steps to spin up a minimalistic Kuberef deployment on VMs aimed for development and testing use-cases:

* Get kuberef code from gerrit ``git clone "https://gerrit.opnfv.org/gerrit/kuberef"``.
* Set ``VENDOR=libvirt-vms``, ``DISTRO=ubuntu1804`` in ``deploy.env``. Additionally, ensure that other environmental variables defined in this file match your setup.
* The hardware and network configurations for the VMs are defined under ``hw_config/libvirt-vms``. Currently, the configuration for one master and one worker VM is defined, but additional VM's can be added as desired. Additionally, the default values of hardware storage, CPU information, etc. can be adapted as per need.
* Once ready, initiate the deployment by running ``dev/deploy_on_vms.sh``.

After the successful completion of the deployment, you can do ``virsh list`` to list the provisioned VM's and connect to them over SSH using user ``root``. The SSH public key of the user is already added by the installer in the VM's. The IP of the VMs can be found under ``hw_config/libvirt-vms/pdf.yaml``.

Verify that all services in the VM's are running by ``kubectl get all --all-namespaces``.

Note that this feature is currently only supported on Ubuntu 18.04. For other OS, additional configuration might be needed.

Validation of the Reference Implementation
===========================================

Kuberef has been validated by running test cases defined in CNTT RC2 Cookbook.
For setting up RC2 Conformance toolchain, please refer to `CNTT RC-2 Chapter 03 <https://github.com/cntt-n/CNTT/blob/master/doc/ref_cert/RC2/chapters/chapter03.md>`_.
