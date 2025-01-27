import os
import platform
import subprocess
import sys

import psutil

def get_windows_parent_process_name():
    try:
        current_process = psutil.Process()
        print(f"Current process: {current_process.parent().parent().name()} -> {current_process.parent().name()} -> {current_process.name()}")

        while True:
            parent = current_process.parent()
            if parent is None:
                break
            parent_name = parent.name().lower()
            if parent_name in ["pwsh.exe", "powershell.exe", "cmd.exe"]:
                return parent_name
            current_process = parent
        return None
    except Exception:
        return None

def main():
    cwd=None
    command = "C:\\Users\\vivihung\\source\\repos\\SuperMarioBros-CSharp-Remake\\debug.ps1"
    #command = ".\\debug.ps1"
    encoding=sys.stdout.encoding

    try:
        shell = os.environ.get("SHELL", "/bin/sh")
        parent_process = None

        # Determine the appropriate shell
        parent_process = get_windows_parent_process_name()
        if parent_process == "powershell.exe":
            command = f"powershell -Command {command}"
        elif parent_process == "pwsh.exe":
                command = f"pwsh.exe -Command {command}"

        print(f"Parent process: {parent_process}")
        print(f"Command: {command}")


        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            shell=True,
            encoding=encoding,
            errors="replace",
            bufsize=0,  # Set bufsize to 0 for unbuffered output
            universal_newlines=True,
            cwd=cwd,
        )

        output = []
        while True:
            chunk = process.stdout.read(1)
            if not chunk:
                break
            print(chunk, end="", flush=True)  # Print the chunk in real-time
            output.append(chunk)  # Store the chunk for later use

        process.wait()
        return process.returncode, "".join(output)
    except Exception as e:
        return 1, str(e)
    

if __name__ == "__main__":
    main()