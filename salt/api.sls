{% from "salt/map.jinja" import salt_settings with context %}
{% set cfg_salt = pillar.get('salt', {}) %}
{% set cfg_api = cfg_salt.get('api', {}) %}
{% set api_users = cfg_api.get('users', {}) %}
{% set htpasswd_file = cfg_api.get('htpasswd_file', '/etc/salt/api-users.htpasswd') %}

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

{% if api_users %}
apache2-utils:
  pkg.installed

{% for username, config in api_users.items() %}
salt-api-user-{{ username }}:
  webutil.user_exists:
    - name: {{ username | tojson }}
    - password: {{ config['password'] | tojson }}
    - htpasswd_file: {{ htpasswd_file | tojson }}
    - update: true
    - require:
      - pkg: apache2-utils
    - require_in:
      - file: salt-api-htpasswd-file
{% endfor %}

salt-api-htpasswd-file:
  file.managed:
    - name: {{ htpasswd_file | tojson }}
    - user: salt
    - group: salt
    - mode: '0600'
    - replace: false
{% endif %}
