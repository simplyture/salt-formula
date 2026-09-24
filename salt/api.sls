{% from "salt/map.jinja" import salt_settings with context %}

include:
  - salt.master

salt-api:
{% if salt_settings.install_packages %}
  pkg.installed:
    - name: {{ salt_settings.salt_api }}
  {%- if salt_settings.version is defined %}
    - version: {{ salt_settings.version }}
  {%- endif %}
{% endif %}
{% if salt_settings.api_service_details.state != 'ignore' %}
  service.{{ salt_settings.api_service_details.state }}:
    - enable: {{ salt_settings.api_service_details.enabled }}
    - name: {{ salt_settings.api_service }}
    {%- if grains.os_family in ['FreeBSD', 'Gentoo'] %}
    - retry: {{ salt_settings.retry_options | json }}
    {%- endif %}
    - require:
      - service: {{ salt_settings.master_service }}
    - watch:
{% if salt_settings.install_packages %}
      - pkg: salt-api
{% endif %}
      - file: salt-master
{% endif %}

{% set api_users = salt['pillar.get']('salt_api:users', {}) %}

apache2-utils:
  pkg.installed

{% for username, config in api_users.items() %}

salt-api-user-{{ username }}:
  webutil.user_exists:
    - name: {{ username | tojson }}
    - password: {{ config['password'] | tojson }}
    - htpasswd_file: /etc/salt/api-users.htpasswd
    - update: true
    - require:
      - pkg: apache2-utils
    - require_in:
      - file: salt-api-htpasswd-file

{% endfor %}

salt-api-htpasswd-file:
  file.managed:
    - name: /etc/salt/api-users.htpasswd
    - user: salt
    - group: salt
    - mode: '0600'
    - replace: false
