# -*- coding: utf-8 -*-
# vim: ft=sls
{%- from "iscsi/map.jinja" import iscsi with context %}

  {%- set provider = iscsi.client.provider %}
  {%- set data = iscsi.initiator[provider|string] %}

  {%- if iscsi.client.pkgs.unwanted %}
    {%- for pkg in iscsi.client.pkgs.unwanted %}
iscsi_initiator_unwanted_pkgs_{{ pkg }}:
  pkg.purged:
    - name: {{ pkg }}
    - require_in:
      - file: iscsi_initiator_service_config
    {% endfor %}
  {%- endif %}

  {%- if iscsi.client.pkgs.wanted %}
    {%- for pkg in iscsi.client.pkgs.wanted %}
iscsi_initiator_wanted_pkgs_{{ pkg }}:
  pkg.installed:
    - name: {{ pkg }}
        {%- if iscsi.client.pkghold %}
    - hold: {{ iscsi.client.pkghold }}
        {%- endif %}
    - reload: True
    - require_in:
      - file: iscsi_initiator_service_config
    {% endfor %}
  {%- endif %}

{%-if iscsi.client.make.wanted and salt['cmd.run']("id iscsi.user", output_loglevel='quiet')%}
  {%- for pkg in [iscsi.client.make.wanted,] %}
iscsi_initiator_make_pkg_{{ pkg }}:
  file.directory:
    - name: /home/{{ iscsi.user }}
    - makedirs: True
    - user: {{ iscsi.user }}
    - dir_mode: '0755'
      {%- if iscsi.client.make.gitrepo %}
  git.latest:
    - name: {{ iscsi.client.make.gitrepo }}/{{ pkg }}.git
    - target: /home/{{ iscsi.user }}/{{ pkg }}
    - user: {{ iscsi.user }}
    - force_clone: True
    - force_fetch: True
    - force_reset: True
    - force_checkout: True
    {% if grains['saltversioninfo'] >= [2017, 7, 0] %}
    - retry:
        attempts: 3
        until: True
        interval: 60
        splay: 10
    {%- endif %}
    - require:
      - file: iscsi_initiator_make_pkg_{{ pkg }}
      {%- endif %}
  cmd.run:
    - cwd: /home/{{ iscsi.user }}/{{ pkg }}
    - name: {{ iscsi.client.make.cmd }}
    - runas: {{ iscsi.user }}
  {% endfor %}
{%- endif %}

iscsi_initiator_service_config:
  file.managed:
    - name: {{ data.man5.config }}
    - source: {{ iscsi.cfgsource }}
    - template: jinja
    - user: root
    - group: {{ iscsi.group }}
    - mode: {{ iscsi.filemode }}
    - makedirs: True
    - context:
        data: {{ data|json }}
        component: 'initiator'
        provider: {{ provider }}
        json: {{ data.man5.format.json|json }}

  {%- if iscsi.kernel.mess_with_kernel and data.man5.kmodule and data.man5.kmoduletext %}
iscsi_initiator_kernel_module:
  file.line:
    - name: {{ iscsi.kernel.modloadfile }}
    - content: {{ data.man5.kmoduletext }}
    - backup: True
        {%- if not iscsi.client.enabled %}
    - mode: delete
  cmd.run:
    - name: {{ iscsi.kernel.modunload }} {{ data.man5.kmodule }}
    - onlyif: {{ iscsi.kernel.modquery }} {{ data.man5.kmodule }}
        {%- else %}
    - mode: ensure
    - after: autoboot_delay.*$
  cmd.run:
    - name: {{ iscsi.kernel.modload }} {{ data.man5.kmodule }}
    - unless: {{ iscsi.kernel.modquery }} {{ data.man5.kmodule }}
    - require:
      - file: iscsi_initiator_kernel_module
        {%- endif %}
    - require_in:
      - service: iscsi_initiator_service
  {%- endif %}

iscsi_initiator_service:
  file.line:
    - onlyif: test "`uname`" = "FreeBSD"
    - name: {{ data.man5.svcloadfile }}
    - content: {{ data.man5.svcloadtext }}
    - backup: True
        {%- if not iscsi.client.enabled %}
    - mode: delete
  service.disabled:
    - enable: False
        {%- else %}
    - mode: ensure
    - after: ^salt.*$
  service.running:
    - enable: True
    - require:
      - file: iscsi_initiator_service_config
    - watch:
      - file: iscsi_initiator_service_config
        {%- endif %}
        {%- if data.man5.svcname is iterable and data.man5.svcname is not string %}
    - names: {{ data.man5.svcname|json }}
        {%- else %}
    - name: {{ data.man5.svcname }}
        {%- endif %}
        {%- if data.man5.kmodule %}
    - unless: {{ iscsi.kernel.modquery }} {{ data.man5.kmodule }}
        {%- endif %}

iscsi_initiator_service_running_failure_explanation:
  test.show_notification:
    - text: |
        In certain circumstances the iscsi initiator service will not start.
        One reason is your kernel version was upgraded and reboot is needed.
        If that's the case then run command:
            'systemctl enable {{ data.man5.svcname }}' && reboot
    - onfail:
      - service: iscsi_initiator_service
    - unless: {{ grains.os_family in ('MacOS', 'Windows') }}   #maybe not needed but no harm
