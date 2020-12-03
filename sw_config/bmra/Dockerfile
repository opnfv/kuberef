FROM centos:7
MAINTAINER "Rihab Banday <rihab.banday@ericsson.com>"

#Install tools needed by BMRA Ansible playbooks
RUN yum -y update && \
    yum -y install git epel-release python36 python-netaddr && \
    yum -y install python-pip && \
    pip install pip==9.0.3 && \
    pip install ansible==2.9.6 jmespath && \
    pip install jinja2 --upgrade

CMD ["bash"]
