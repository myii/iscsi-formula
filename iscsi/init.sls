# -*- coding: utf-8 -*-
# vim: ft=sls

include:
  - iscsi.target
  - iscsi.initiator
  #Putting isns last avoids /etc/isns/isnsd.conf file conflict on Arch
  - iscsi.isns
