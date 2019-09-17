# -*- coding: utf-8 -*-
# vim: ft=sls

{#- Get the `tplroot` from `tpldir` #}
{%- set tplroot = tpldir.split('/')[0] %}
{%- set sls_config_install = tplroot ~ '.target.config.install' %}
{%- from tplroot ~ "/map.jinja" import iscsi with context %}

include:
  - {{ sls_config_install }}

    {%- if grains.os_family == 'FreeBSD' %}
iscsi-target-service-install-file-line-freebsd:
  file.line:
    - name: {{ iscsi.config.name.modprobe }}
    - content: 'ctld_env="-u"'
    - backup: True
        {%- if iscsi.target.enabled %}
    - mode: ensure
    - after: 'autoboot_delay.*'
        {%- else %}
    - mode: delete
        {%- endif %}
    {%- endif %}

    {%- set servicename = iscsi.config.servicename[iscsi.target.provider] %}
iscsi-target-service-install-service-running:
        {%- if not iscsi.target.enabled %}
  service.dead:
    - name: {{ servicename }}
    - enable: False
        {%- else %}
  service.running:
    - name: {{ servicename }}
    - enable: True
    - onfail_in:
      - test: iscsi-target-service-install-failure-explanation
    - require:
      - sls: {{ sls_config_install }}
    - watch:
      - file: iscsi-target-config-install-file-managed
        {%- endif %}
        {%- if servicename is iterable and servicename is not string %}
    - names: {{ servicename|json }}
        {%- else %}
    - name: {{ servicename }}
        {%- endif %}

iscsi-target-service-install-failure-explanation:
  test.show_notification:
    - text: |
        In certain circumstances the iscsi target service will not start.
        * your configuration file may be incorrect.
        * your kernel was upgraded but not activated by reboot
            'systemctl enable {{ servicename }}' && reboot
    - unless: {{ grains.os_family in ('MacOS', 'Windows') }}   #maybe not needed but no harm
