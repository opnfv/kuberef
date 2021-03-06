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

Installing and configuring the prerequisites will depend on the operating system installed on the jump server. Below are additional details for setting up some of the more popular distributions.

**Ubuntu 20.04 LTS**

Install packages using Apt

* ``apt-get install qemu-kvm libvirt-daemon-system libvirt-clients genisoimage virt-manager bridge-utils python3-libvirt git jq``
* Some of the packages might be installed already
* Start libvirtd if it isn't running using ``service libvirtd start``
* Add user to libvirt group using ``adduser `id -un` libvirt``
* Log out and in on the current user to update the groups

If ``python`` isn't available in the path, consider adding a symlink for Python3

* ``ln -s /usr/bin/python3 /usr/bin/python``

Install Ansible

* ``apt-add-repository --yes --update ppa:ansible/ansible``
* ``apt-get install ansible``

Install ``yq`` binary from Github

* Find the correct build of version `v3.4.1 <https://github.com/mikefarah/yq/releases/tag/3.4.1>`_
* Place the binary in ``/usr/bin/yq`` and make it executable ``chmod +x /usr/bin/yq``

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

Deployment
=============================

Please refer to Chapter 4 of `CNTT RI-2 Documentation <https://github.com/cntt-n/CNTT/blob/master/doc/ref_impl/cntt-ri2/chapters/chapter04.md>`_
for instructions to get started with the deployment.

Once the deployment is successful, you will have a fully functional RI-2 setup!

Validation of the Reference Implementation
===========================================

Kuberef has been validated by running test cases defined in CNTT RC2 Cookbook.
For setting up RC2 Conformance toolchain, please refer to `CNTT RC-2 Chapter 03 <https://github.com/cntt-n/CNTT/blob/master/doc/ref_cert/RC2/chapters/chapter03.md>`_.
