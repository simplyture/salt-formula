{%- set tplroot = tpldir.split('/')[0] %}
{%- from tplroot ~ "/map.jinja" import salt_settings with context %}

{%- set cfg_ssh = salt_settings.master.ssh %}
{%- set ssh_user = cfg_ssh.user %}
{%- set ssh_group = cfg_ssh.group %}
{%- set ssh_dir = cfg_ssh.home ~ '/.ssh' %}

include:
  - {{ tplroot }}.master

{%- if grains.kernel != 'Windows' %}

salt-master-ssh-dir:
  file.directory:
    - name: {{ ssh_dir }}
    - user: {{ ssh_user }}
    - group: {{ ssh_group }}
    - mode: '0700'
    {%- if salt_settings.install_packages %}
    - require:
      - pkg: salt-master
    {%- endif %}

    {%- for name, key in cfg_ssh['keys'].items() %}
      {#- public is optional: ssh derives it, pygit2 (gitfs_pubkey) needs the file #}
      {%- for type, suffix in [('private', ''), ('public', '.pub')] if key.get(type) %}
salt-master-ssh-key-{{ name }}-{{ type }}:
  file.managed:
    - name: {{ ssh_dir }}/{{ name }}{{ suffix }}
    {#- OpenSSH rejects a private key without the trailing newline #}
    - contents: {{ (key[type].rstrip('\n') ~ '\n') | json }}
    - user: {{ ssh_user }}
    - group: {{ ssh_group }}
    - mode: {{ '0600' if type == 'private' else '0644' }}
    - show_changes: false
    - require:
      - file: salt-master-ssh-dir
      {%- endfor %}
    {%- endfor %}

    {%- if cfg_ssh.config %}
salt-master-ssh-config:
  file.managed:
    - name: {{ ssh_dir }}/config
    - source: salt://{{ tplroot }}/files/ssh_config.jinja
    - template: jinja
    - user: {{ ssh_user }}
    - group: {{ ssh_group }}
    - mode: '0600'
    - require:
      - file: salt-master-ssh-dir
    - context:
        hosts: {{ cfg_ssh.config | json }}
        ssh_dir: {{ ssh_dir | json }}
    {%- endif %}

    {%- if cfg_ssh.known_hosts %}
salt-master-ssh-known-hosts:
  file.managed:
    - name: {{ ssh_dir }}/known_hosts
    - contents: |
        # This file managed by Salt, do not edit by hand!!
        {%- for hosts, keys in cfg_ssh.known_hosts.items() %}
          {%- for key in ([keys] if keys is string else keys) %}
        {{ hosts }} {{ key }}
          {%- endfor %}
        {%- endfor %}
    - user: {{ ssh_user }}
    - group: {{ ssh_group }}
    - mode: '0644'
    - require:
      - file: salt-master-ssh-dir
    {%- endif %}

{%- endif %}
