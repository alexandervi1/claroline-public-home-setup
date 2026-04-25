#!/usr/bin/env python3
"""
Parchea platform_options.json para activar el contexto público en Claroline Connect v15.
Cambia home.type de "none" a "tool".

Uso:
    python3 patch_platform_options.py --host IP --user SSH_USER --password SSH_PASS
    python3 patch_platform_options.py --host IP --key ~/.ssh/id_rsa --user SSH_USER
"""
import argparse
import json
import sys

try:
    import paramiko
except ImportError:
    sys.exit("Error: instala paramiko primero: pip install paramiko")

PLATFORM_OPTIONS_PATH = "/var/www/claroline/files/config/platform_options.json"

def main():
    parser = argparse.ArgumentParser(description="Patch Claroline platform_options.json via SSH")
    parser.add_argument("--host",     required=True,  help="IP o hostname del servidor")
    parser.add_argument("--user",     required=True,  help="Usuario SSH con sudo")
    parser.add_argument("--password", default=None,   help="Contrasena SSH (y sudo)")
    parser.add_argument("--key",      default=None,   help="Ruta a clave privada SSH")
    parser.add_argument("--port",     type=int, default=22)
    args = parser.parse_args()

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    connect_kwargs = dict(hostname=args.host, username=args.user, port=args.port, timeout=15)
    if args.key:
        connect_kwargs["key_filename"] = args.key
    if args.password:
        connect_kwargs["password"] = args.password

    print(f"Conectando a {args.host}...")
    client.connect(**connect_kwargs)

    sudo_pw = f"echo {args.password} | sudo -S" if args.password else "sudo"
    stdin, stdout, stderr = client.exec_command(f"{sudo_pw} cat {PLATFORM_OPTIONS_PATH} 2>&1")
    content = stdout.read().decode("utf-8")

    try:
        config = json.loads(content)
    except json.JSONDecodeError as e:
        sys.exit(f"Error parseando JSON: {e}\nContenido: {content[:200]}")

    current = config.get("home", {})
    print(f"Estado actual:  home = {json.dumps(current)}")

    if current.get("type") == "tool":
        print("Ya tiene type=tool — no se necesitan cambios.")
        client.close()
        return

    config["home"] = {"type": "tool", "data": None}
    new_content = json.dumps(config, ensure_ascii=False, indent=4)

    sftp = client.open_sftp()
    with sftp.open("/tmp/platform_options_patched.json", "w") as f:
        f.write(new_content)
    sftp.close()

    stdin, stdout, stderr = client.exec_command(
        f"{sudo_pw} cp /tmp/platform_options_patched.json {PLATFORM_OPTIONS_PATH} && "
        f"{sudo_pw} chown www-data:www-data {PLATFORM_OPTIONS_PATH}"
    )
    stdout.channel.recv_exit_status()
    err = stderr.read().decode()
    if err.strip() and "password" not in err.lower():
        sys.exit(f"Error al copiar: {err}")

    print(f"Aplicado:       home = {{\"type\": \"tool\", \"data\": null}}")
    print("platform_options.json actualizado correctamente.")
    client.close()

if __name__ == "__main__":
    main()
