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
salt-api-htpasswd-package:
  pkg.installed:
    - name: apache2-utils
    - reload_modules: true

{% for username, config in api_users.items() %}
salt-api-user-{{ username }}:
  module.run:
    - webutil.useradd:
      - pwfile: {{ htpasswd_file | tojson }}
      - user: {{ username | tojson }}
      - password: {{ config['password'] | tojson }}
    - unless:
      - fun: webutil.verify
        pwfile: {{ htpasswd_file | tojson }}
        user: {{ username | tojson }}
        password: {{ config['password'] | tojson }}
    - require:
      - pkg: salt-api-htpasswd-package
{% endfor %}

salt-api-htpasswd-file:
  file.managed:
    - name: {{ htpasswd_file | tojson }}
    - user: salt
    - group: salt
    - mode: '0600'
    - replace: false
    - require:
{% for username in api_users %}
      - module: salt-api-user-{{ username }}
{% endfor %}
{% endif %}
