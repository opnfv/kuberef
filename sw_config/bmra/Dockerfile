# SPDX-FileCopyrightText: 2021 Anuket contributors
#
# SPDX-License-Identifier: Apache-2.0

FROM centos:7
MAINTAINER "Rihab Banday <rihab.banday@ericsson.com>"

#Install tools needed by BMRA Ansible playbooks
RUN yum -y update && \
    yum -y install git epel-release python36 python-netaddr && \
    yum -y install python-pip && \
    pip install --no-cache-dir pip==9.0.3 && \
    pip install --no-cache-dir ansible==2.9.20 jmespath && \
    pip install --no-cache-dir jinja2 --upgrade

CMD ["bash"]
